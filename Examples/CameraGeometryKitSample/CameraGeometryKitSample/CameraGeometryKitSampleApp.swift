import AVFoundation
import CameraGeometryKit
import CoreVideo
import PhotosUI
import SwiftUI
import UIKit
import Vision

@main
struct CameraGeometryKitSampleApp: App {
    var body: some Scene {
        WindowGroup { SampleRootView() }
    }
}

private enum SampleTab: Hashable { case capture, geometry, vision, depth, image }

private struct SampleRootView: View {
    @State private var selection: SampleTab = .capture

    var body: some View {
        TabView(selection: $selection) {
            Group { if selection == .capture { CameraSampleView() } else { Color.black } }
                .tag(SampleTab.capture)
                .tabItem { Label("Capture", systemImage: "camera") }
            Group { if selection == .geometry { GeometryLabView() } else { Color.black } }
                .tag(SampleTab.geometry)
                .tabItem { Label("Geometry", systemImage: "scope") }
            Group { if selection == .vision { VisionLabView() } else { Color.black } }
                .tag(SampleTab.vision)
                .tabItem { Label("Vision", systemImage: "viewfinder") }
            Group { if selection == .depth { DepthLabView() } else { Color.black } }
                .tag(SampleTab.depth)
                .tabItem { Label("Depth", systemImage: "square.3.layers.3d") }
            Group { if selection == .image { ImageLabView() } else { Color.black } }
                .tag(SampleTab.image)
                .tabItem { Label("Image", systemImage: "photo") }
        }
    }
}

// MARK: - Shared

@MainActor
private struct LabCameraPreview: UIViewRepresentable {
    let camera: CameraCaptureSession
    let deviceUniqueID: String?
    let videoGravity: AVLayerVideoGravity

    init(camera: CameraCaptureSession, deviceUniqueID: String?, videoGravity: AVLayerVideoGravity = .resizeAspect) {
        self.camera = camera
        self.deviceUniqueID = deviceUniqueID
        self.videoGravity = videoGravity
    }

    func makeUIView(context: Context) -> LabPreviewContainerView {
        let view = LabPreviewContainerView()
        view.configure(camera: camera, deviceUniqueID: deviceUniqueID, videoGravity: videoGravity)
        return view
    }

    func updateUIView(_ view: LabPreviewContainerView, context: Context) {
        view.configure(camera: camera, deviceUniqueID: deviceUniqueID, videoGravity: videoGravity)
    }
}

@MainActor
private final class LabPreviewContainerView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    private var previewRotationBinding: CameraPreviewRotationBinding?
    private var observedDeviceUniqueID: String?

    private var previewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else { preconditionFailure("AVCaptureVideoPreviewLayer required") }
        return layer
    }

    func configure(camera: CameraCaptureSession, deviceUniqueID: String?, videoGravity: AVLayerVideoGravity) {
        if previewLayer.session !== camera.captureSession { previewLayer.session = camera.captureSession }
        if previewLayer.videoGravity != videoGravity { previewLayer.videoGravity = videoGravity }
        guard observedDeviceUniqueID != deviceUniqueID || previewRotationBinding == nil else { return }
        previewRotationBinding?.stop()
        previewRotationBinding = nil
        observedDeviceUniqueID = deviceUniqueID
        if deviceUniqueID != nil { previewRotationBinding = camera.bindPreviewRotation(to: previewLayer) }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
        previewRotationBinding?.refresh()
    }
}

private struct LabCameraSwitchButton: View {
    let position: CameraPosition
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.triangle.2.circlepath.camera")
                .font(.title3.weight(.semibold))
                .frame(width: 42, height: 42)
                .background(Color.black.opacity(0.76), in: Circle())
                .foregroundStyle(Color.white)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityLabel(position == .front ? "背面カメラに切り替え" : "前面カメラに切り替え")
    }
}

private struct LabHUD<Content: View>: View {
    let title: String
    let content: () -> Content

    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption2.monospaced().weight(.bold))
            content()
        }
        .font(.caption2.monospaced())
        .foregroundStyle(Color.white)
        .padding(8)
        .background(Color.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Geometry

@MainActor
private final class GeometryLabModel: ObservableObject {
    @Published private(set) var state = CameraCaptureSessionState(isConfigured: false, isRunning: false, cameraPosition: .unspecified, deviceUniqueID: nil, deviceName: nil)
    @Published private(set) var frameSize = CGSize.zero
    @Published private(set) var errorMessage: String?
    let camera = CameraCaptureSession(sessionPreset: .high)

    func run() async {
        do {
            state = try await camera.start(position: .back)
            let camera = camera
            let consumer = Task.detached(priority: .userInitiated) { [weak self] in
                var iterator = camera.frameStream.frames.makeAsyncIterator()
                var lastSize = CGSize.zero
                while !Task.isCancelled, let frame = await iterator.next() {
                    let size = frame.geometry.pixelSize
                    guard size != lastSize else { continue }
                    lastSize = size
                    await MainActor.run { [weak self] in self?.frameSize = size }
                }
            }
            await withTaskCancellationHandler { await consumer.value } onCancel: { consumer.cancel() }
        } catch is CancellationError {
        } catch { if !Task.isCancelled { errorMessage = error.localizedDescription } }
        await camera.stop()
        if !Task.isCancelled { state = camera.currentState }
    }

    func switchCamera() async {
        guard state.isRunning else { return }
        do {
            state = try await camera.setCameraPosition(state.cameraPosition == .front ? .back : .front)
            frameSize = .zero
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct GeometryLabView: View {
    @StateObject private var model = GeometryLabModel()
    @State private var contentMode: CameraContentMode = .aspectFit
    @State private var tappedCanonical: CanonicalPoint?
    @State private var lastTapWasOutside = false

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let mirrored = model.state.cameraPosition == .front
                let mapping = ViewportMapping(imageSize: model.frameSize, viewportSize: proxy.size, contentMode: contentMode, isMirrored: mirrored)
                ZStack {
                    Color.black
                    LabCameraPreview(camera: model.camera, deviceUniqueID: model.state.deviceUniqueID, videoGravity: contentMode == .aspectFit ? .resizeAspect : .resizeAspectFill)
                    if let imageRect = mapping.imageRect {
                        Rectangle().stroke(Color.white.opacity(0.35), lineWidth: 1)
                            .frame(width: imageRect.width, height: imageRect.height)
                            .position(x: imageRect.midX, y: imageRect.midY)
                            .allowsHitTesting(false)
                    }
                    if let tappedCanonical, let point = mapping.viewportPoint(from: tappedCanonical) {
                        ZStack {
                            Circle().stroke(Color.cyan, lineWidth: 2).frame(width: 22, height: 22)
                            Rectangle().fill(Color.cyan).frame(width: 30, height: 1)
                            Rectangle().fill(Color.cyan).frame(width: 1, height: 30)
                        }.position(point).allowsHitTesting(false)
                    }
                    VStack {
                        HStack(alignment: .top) {
                            LabHUD("VIEWPORT → CANONICAL") {
                                Text(model.state.deviceName ?? "starting camera…")
                                if let p = tappedCanonical { Text(String(format: "canonical: %.4f, %.4f", p.x, p.y)) }
                                else { Text(lastTapWasOutside ? "tap: letterbox" : "tap preview to inspect mapping") }
                                if let error = model.errorMessage { Text(error).foregroundStyle(Color.red) }
                            }
                            Spacer()
                            LabCameraSwitchButton(position: model.state.cameraPosition, enabled: model.state.isRunning) { Task { await model.switchCamera() } }
                        }
                        Spacer()
                        Picker("Content mode", selection: $contentMode) {
                            Text("Fit").tag(CameraContentMode.aspectFit)
                            Text("Fill").tag(CameraContentMode.aspectFill)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 220)
                        .padding(8)
                        .background(Color.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 6))
                    }.padding(10)
                }
                .contentShape(Rectangle())
                .gesture(SpatialTapGesture().onEnded { value in
                    let p = mapping.canonicalPoint(fromViewport: value.location)
                    tappedCanonical = p
                    lastTapWasOutside = p == nil
                })
            }
            .navigationTitle("Geometry Lab")
            .navigationBarTitleDisplayMode(.inline)
            .task { await model.run() }
        }
    }
}

// MARK: - Vision

@MainActor
private final class VisionLabModel: ObservableObject {
    @Published private(set) var state = CameraCaptureSessionState(isConfigured: false, isRunning: false, cameraPosition: .unspecified, deviceUniqueID: nil, deviceName: nil)
    @Published private(set) var faces: [CanonicalRect] = []
    @Published private(set) var frameSize = CGSize.zero
    @Published private(set) var acceptedFrameID: UInt64?
    @Published private(set) var errorMessage: String?
    let camera = CameraCaptureSession(sessionPreset: .high)

    private lazy var worker = CameraVisionWorker<[CanonicalRect]>(
        makeRequest: { DetectFaceRectanglesRequest() },
        map: { $0.map { VisionGeometry.canonicalRect(for: $0) } },
        delivery: { [weak self] output in self?.faces = output.value; self?.acceptedFrameID = output.frameID.rawValue }
    )

    func run() async {
        do {
            state = try await camera.start(position: .back)
            let camera = camera
            let worker = worker
            let consumer = Task.detached(priority: .userInitiated) { [weak self] in
                var iterator = camera.frameStream.frames.makeAsyncIterator()
                var lastSize = CGSize.zero
                while !Task.isCancelled, let frame = await iterator.next() {
                    await worker.submit(frame)
                    let size = frame.geometry.pixelSize
                    if size != lastSize { lastSize = size; await MainActor.run { [weak self] in self?.frameSize = size } }
                }
            }
            await withTaskCancellationHandler { await consumer.value } onCancel: { consumer.cancel() }
        } catch is CancellationError {
        } catch { if !Task.isCancelled { errorMessage = error.localizedDescription } }
        await worker.invalidate()
        await camera.stop()
        if !Task.isCancelled { state = camera.currentState }
    }

    func switchCamera() async {
        guard state.isRunning else { return }
        do {
            await worker.invalidate()
            state = try await camera.setCameraPosition(state.cameraPosition == .front ? .back : .front)
            faces = []; frameSize = .zero; acceptedFrameID = nil; errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct VisionLabView: View {
    @StateObject private var model = VisionLabModel()
    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let mapping = ViewportMapping(imageSize: model.frameSize, viewportSize: proxy.size, contentMode: .aspectFit, isMirrored: model.state.cameraPosition == .front)
                ZStack {
                    Color.black
                    LabCameraPreview(camera: model.camera, deviceUniqueID: model.state.deviceUniqueID)
                    ForEach(Array(model.faces.enumerated()), id: \.offset) { index, face in
                        if let rect = mapping.viewportRect(from: face) {
                            ZStack(alignment: .topLeading) {
                                Rectangle().stroke(Color.yellow, lineWidth: 3)
                                Text("FACE \(index + 1)").font(.caption2.monospaced().weight(.bold)).foregroundStyle(Color.black).padding(3).background(Color.yellow)
                            }.frame(width: rect.width, height: rect.height).position(x: rect.midX, y: rect.midY).allowsHitTesting(false)
                        }
                    }
                    VStack {
                        HStack(alignment: .top) {
                            LabHUD("VISION / FACE RECTANGLES") {
                                Text(model.state.deviceName ?? "starting camera…")
                                Text("faces: \(model.faces.count)")
                                Text("accepted frame: \(model.acceptedFrameID.map(String.init) ?? "—")")
                                if let error = model.errorMessage { Text(error).foregroundStyle(Color.red) }
                            }
                            Spacer()
                            LabCameraSwitchButton(position: model.state.cameraPosition, enabled: model.state.isRunning) { Task { await model.switchCamera() } }
                        }
                        Spacer()
                    }.padding(10)
                }
            }
            .navigationTitle("Vision Lab")
            .navigationBarTitleDisplayMode(.inline)
            .task { await model.run() }
        }
    }
}

// MARK: - Depth

private struct DepthSnapshot: Sendable {
    let frameID: UInt64
    let colorSize: CGSize
    let depthSize: CGSize?
    let centerDepthMeters: Float?
    let columns: Int
    let rows: Int
    let meters: [Float?]
}

@MainActor
private final class DepthLabModel: ObservableObject {
    @Published private(set) var state = CameraCaptureSessionState(isConfigured: false, isRunning: false, cameraPosition: .unspecified, deviceUniqueID: nil, deviceName: nil)
    @Published private(set) var snapshot: DepthSnapshot?
    @Published private(set) var errorMessage: String?
    let devices: [CameraDeviceInfo]
    let camera = CameraCaptureSession(sessionPreset: .inputPriority, depthConfiguration: CameraDepthCaptureConfiguration(isFilteringEnabled: false))

    init() {
        devices = CameraDeviceDiscovery.availableDeviceInfos().filter { info in
            guard info.supportsDepthData, let device = AVCaptureDevice(uniqueID: info.uniqueID) else { return false }
            return device.activeFormat.supportedDepthDataFormats.contains {
                let type = CMFormatDescriptionGetMediaSubType($0.formatDescription)
                return type == kCVPixelFormatType_DepthFloat32 || type == kCVPixelFormatType_DepthFloat16
            }
        }
    }

    func run() async {
        guard let initial = devices.first(where: { $0.position == .back }) ?? devices.first else {
            errorMessage = "No active-format-compatible depth camera."
            return
        }
        do {
            state = try await camera.start(request: CameraDeviceRequest(device: initial))
            guard let stream = camera.synchronizedFrameStream else { errorMessage = "Synchronized depth stream unavailable."; return }
            let consumer = Task.detached(priority: .utility) { [weak self] in
                var iterator = stream.frames.makeAsyncIterator()
                let clock = ContinuousClock(); var last = clock.now - .seconds(2)
                while !Task.isCancelled, let frame = await iterator.next() {
                    let now = clock.now; guard last.duration(to: now) >= .milliseconds(500) else { continue }; last = now
                    let value = Self.makeSnapshot(frame)
                    await MainActor.run { [weak self] in self?.snapshot = value }
                }
            }
            await withTaskCancellationHandler { await consumer.value } onCancel: { consumer.cancel() }
        } catch is CancellationError {
        } catch { if !Task.isCancelled { errorMessage = error.localizedDescription } }
        await camera.stop(); if !Task.isCancelled { state = camera.currentState }
    }

    func switchCamera() async {
        let target: CameraPosition = state.cameraPosition == .front ? .back : .front
        guard let device = devices.first(where: { $0.position == target }) else { errorMessage = "No compatible \(target.rawValue) depth camera."; return }
        do { state = try await camera.setCamera(CameraDeviceRequest(device: device)); snapshot = nil; errorMessage = nil }
        catch { errorMessage = error.localizedDescription }
    }

    var canSwitch: Bool {
        let target: CameraPosition = state.cameraPosition == .front ? .back : .front
        return devices.contains { $0.position == target }
    }

    nonisolated private static func makeSnapshot(_ frame: CameraSynchronizedFrame) -> DepthSnapshot {
        guard let depth = frame.depth else { return DepthSnapshot(frameID: frame.color.id.rawValue, colorSize: frame.color.geometry.pixelSize, depthSize: nil, centerDepthMeters: nil, columns: 5, rows: 3, meters: Array(repeating: nil, count: 15)) }
        let sampled = sampleDepth(depth)
        return DepthSnapshot(frameID: frame.color.id.rawValue, colorSize: frame.color.geometry.pixelSize, depthSize: depth.geometry.pixelSize, centerDepthMeters: sampled.3, columns: sampled.0, rows: sampled.1, meters: sampled.2)
    }

    nonisolated private static func sampleDepth(_ frame: CameraDepthFrame) -> (Int, Int, [Float?], Float?) {
        let map = frame.depthMap
        CVPixelBufferLockBaseAddress(map, .readOnly); defer { CVPixelBufferUnlockBaseAddress(map, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(map) else { return (5, 3, Array(repeating: nil, count: 15), nil) }
        let width = CVPixelBufferGetWidth(map), height = CVPixelBufferGetHeight(map), bytes = CVPixelBufferGetBytesPerRow(map), format = CVPixelBufferGetPixelFormatType(map)
        func value(_ x: Int, _ y: Int) -> Float? {
            let row = base.advanced(by: y * bytes); let v: Float
            if format == kCVPixelFormatType_DepthFloat32 { v = row.assumingMemoryBound(to: Float.self)[x] }
            else if format == kCVPixelFormatType_DepthFloat16 { v = Float(row.assumingMemoryBound(to: Float16.self)[x]) }
            else { return nil }
            return v.isFinite && v > 0 ? v : nil
        }
        let columns = 5, rows = 3
        var values: [Float?] = []
        for r in 0..<rows { for c in 0..<columns { values.append(value(((c * 2 + 1) * width) / (columns * 2), ((r * 2 + 1) * height) / (rows * 2))) } }
        return (columns, rows, values, value(width / 2, height / 2))
    }
}

private struct DepthLabView: View {
    @StateObject private var model = DepthLabModel()
    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack {
                    Color.black
                    LabCameraPreview(camera: model.camera, deviceUniqueID: model.state.deviceUniqueID)
                    if let s = model.snapshot, let depthSize = s.depthSize {
                        let mapping = ViewportMapping(imageSize: depthSize, viewportSize: proxy.size, contentMode: .aspectFit, isMirrored: model.state.cameraPosition == .front)
                        ForEach(0..<(s.columns * s.rows), id: \.self) { index in
                            let r = index / s.columns, c = index % s.columns
                            let canonical = CanonicalPoint(x: (CGFloat(c) + 0.5) / CGFloat(s.columns), y: (CGFloat(r) + 0.5) / CGFloat(s.rows))
                            if let point = mapping.viewportPoint(from: canonical) {
                                Text(s.meters[index].map { String(format: "%.1f", $0) } ?? "—")
                                    .font(.caption2.monospaced().weight(.semibold)).foregroundStyle(Color.white).padding(3)
                                    .background(Color.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 4)).position(point).allowsHitTesting(false)
                            }
                        }
                    }
                    VStack {
                        HStack(alignment: .top) {
                            LabHUD("SYNCHRONIZED DEPTH") {
                                Text(model.state.deviceName ?? "starting depth camera…")
                                Text("compatible devices: \(model.devices.count)")
                                if let s = model.snapshot {
                                    Text("frame: \(s.frameID)")
                                    Text("RGB: \(Int(s.colorSize.width)) × \(Int(s.colorSize.height))")
                                    Text("depth: \(s.depthSize.map { "\(Int($0.width)) × \(Int($0.height))" } ?? "dropped")")
                                    Text("center: \(s.centerDepthMeters.map { String(format: "%.2f m", $0) } ?? "—")")
                                } else { Text("waiting for RGB + depth…") }
                                if let error = model.errorMessage { Text(error).foregroundStyle(Color.red) }
                            }
                            Spacer()
                            LabCameraSwitchButton(position: model.state.cameraPosition, enabled: model.state.isRunning && model.canSwitch) { Task { await model.switchCamera() } }
                        }
                        Spacer()
                    }.padding(10)
                }
            }
            .navigationTitle("Depth Lab")
            .navigationBarTitleDisplayMode(.inline)
            .task { await model.run() }
        }
    }
}

// MARK: - Image

private struct ImageLabView: View {
    @State private var pickerItem: PhotosPickerItem?
    @State private var sourceImage: UIImage?
    @State private var canonicalImage: UIImage?
    @State private var downsampledImage: UIImage?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    PhotosPicker(selection: $pickerItem, matching: .images) { Label("Choose Image", systemImage: "photo.on.rectangle") }.buttonStyle(.borderedProminent)
                    if let sourceImage, let canonicalImage, let downsampledImage {
                        imageCard("Source", sourceImage)
                        imageCard("Canonical", canonicalImage)
                        imageCard("Downsampled ≤ 1600 px", downsampledImage)
                    } else {
                        ContentUnavailableView("Select an image", systemImage: "photo", description: Text("Tests UIImage canonicalization and preview downsampling."))
                    }
                    if let errorMessage { Text(errorMessage).font(.caption).foregroundStyle(Color.red) }
                }.padding()
            }
            .navigationTitle("Image Lab")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: pickerItem) { await loadImage() }
        }
    }

    private func imageCard(_ title: String, _ image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 220).frame(maxWidth: .infinity).background(Color.black)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func loadImage() async {
        guard let pickerItem else { return }
        do {
            guard let data = try await pickerItem.loadTransferable(type: Data.self), let image = UIImage(data: data) else { errorMessage = "Could not decode selected image."; return }
            let canonical = image.cameraGeometryCanonicalized()
            sourceImage = image
            canonicalImage = canonical
            downsampledImage = canonical.cameraGeometryDownsampled(maxPixelDimension: 1600)
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }
}
