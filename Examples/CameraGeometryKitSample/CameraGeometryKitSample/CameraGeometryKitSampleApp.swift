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
        WindowGroup {
            SampleRootView()
        }
    }
}

private struct SampleRootView: View {
    var body: some View {
        TabView {
            CameraSampleView()
                .tabItem { Label("Capture", systemImage: "camera") }

            GeometryLabView()
                .tabItem { Label("Geometry", systemImage: "square.resize") }

            VisionLabView()
                .tabItem { Label("Vision", systemImage: "viewfinder") }

            DepthLabView()
                .tabItem { Label("Depth", systemImage: "square.3.layers.3d") }

            ImageLabView()
                .tabItem { Label("Image", systemImage: "photo") }
        }
    }
}

// MARK: - Shared live preview

@MainActor
private struct LabCameraPreview: UIViewRepresentable {
    let camera: CameraCaptureSession
    let deviceUniqueID: String?

    func makeUIView(context: Context) -> LabPreviewContainerView {
        let view = LabPreviewContainerView()
        view.configure(camera: camera, deviceUniqueID: deviceUniqueID)
        return view
    }

    func updateUIView(_ view: LabPreviewContainerView, context: Context) {
        view.configure(camera: camera, deviceUniqueID: deviceUniqueID)
    }
}

@MainActor
private final class LabPreviewContainerView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    private var previewRotationBinding: CameraPreviewRotationBinding?
    private var observedDeviceUniqueID: String?

    private var previewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            preconditionFailure("LabPreviewContainerView requires AVCaptureVideoPreviewLayer")
        }
        return layer
    }

    func configure(camera: CameraCaptureSession, deviceUniqueID: String?) {
        if previewLayer.session !== camera.captureSession {
            previewLayer.session = camera.captureSession
        }
        if previewLayer.videoGravity != .resizeAspect {
            previewLayer.videoGravity = .resizeAspect
        }

        guard observedDeviceUniqueID != deviceUniqueID || previewRotationBinding == nil else { return }
        previewRotationBinding?.stop()
        previewRotationBinding = nil
        observedDeviceUniqueID = deviceUniqueID

        if deviceUniqueID != nil {
            previewRotationBinding = camera.bindPreviewRotation(to: previewLayer)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
        previewRotationBinding?.refresh()
    }
}

// MARK: - Geometry

private struct GeometryLabView: View {
    @State private var contentMode: CameraContentMode = .aspectFit
    @State private var mirrored = false
    @State private var tappedCanonical: CanonicalPoint?

    private let imageSize = CGSize(width: 1920, height: 1080)
    private let testRect = CanonicalRect(x: 0.22, y: 0.18, width: 0.34, height: 0.42)

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack {
                    Picker("Mode", selection: $contentMode) {
                        Text("Fit").tag(CameraContentMode.aspectFit)
                        Text("Fill").tag(CameraContentMode.aspectFill)
                    }
                    .pickerStyle(.segmented)

                    Toggle("Mirror", isOn: $mirrored)
                        .labelsHidden()
                    Text("Mirror")
                        .font(.caption)
                }
                .padding(.horizontal)

                GeometryReader { proxy in
                    let mapping = ViewportMapping(
                        imageSize: imageSize,
                        viewportSize: proxy.size,
                        contentMode: contentMode,
                        isMirrored: mirrored
                    )

                    ZStack(alignment: .topLeading) {
                        Color.black

                        if let imageRect = mapping.imageRect {
                            Rectangle()
                                .fill(Color.white.opacity(0.12))
                                .overlay {
                                    Canvas { context, size in
                                        let step = size.width / 8
                                        for index in 1..<8 {
                                            let x = CGFloat(index) * step
                                            var path = Path()
                                            path.move(to: CGPoint(x: x, y: 0))
                                            path.addLine(to: CGPoint(x: x, y: size.height))
                                            context.stroke(path, with: .color(.white.opacity(0.22)), lineWidth: 1)
                                        }
                                        let yStep = size.height / 5
                                        for index in 1..<5 {
                                            let y = CGFloat(index) * yStep
                                            var path = Path()
                                            path.move(to: CGPoint(x: 0, y: y))
                                            path.addLine(to: CGPoint(x: size.width, y: y))
                                            context.stroke(path, with: .color(.white.opacity(0.22)), lineWidth: 1)
                                        }
                                    }
                                }
                                .frame(width: imageRect.width, height: imageRect.height)
                                .position(x: imageRect.midX, y: imageRect.midY)
                        }

                        if let rect = mapping.viewportRect(from: testRect) {
                            Rectangle()
                                .stroke(Color.yellow, lineWidth: 3)
                                .frame(width: rect.width, height: rect.height)
                                .position(x: rect.midX, y: rect.midY)
                        }

                        if let tappedCanonical,
                           let point = mapping.viewportPoint(from: tappedCanonical) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 14, height: 14)
                                .position(point)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { point in
                        tappedCanonical = mapping.canonicalPoint(fromViewport: point)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 4) {
                    Text("ViewportMapping • CanonicalPoint • CanonicalRect")
                        .font(.caption.monospaced().weight(.semibold))
                    if let point = tappedCanonical {
                        Text(String(format: "tap canonical  x %.4f  y %.4f  inside %@", point.x, point.y, point.isInsideUnitSquare ? "true" : "false"))
                    } else {
                        Text("Tap the viewport. Letterbox taps return nil in Fit mode.")
                    }
                    Text(String(format: "test rect  x %.2f y %.2f w %.2f h %.2f", testRect.x, testRect.y, testRect.width, testRect.height))
                }
                .font(.caption2.monospaced())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .navigationTitle("Geometry Lab")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Vision

@MainActor
private final class VisionLabModel: ObservableObject {
    @Published private(set) var state = CameraCaptureSessionState(
        isConfigured: false,
        isRunning: false,
        cameraPosition: .unspecified,
        deviceUniqueID: nil,
        deviceName: nil
    )
    @Published private(set) var faces: [CanonicalRect] = []
    @Published private(set) var frameSize = CGSize.zero
    @Published private(set) var acceptedFrameID: UInt64?
    @Published private(set) var errorMessage: String?

    let camera = CameraCaptureSession(sessionPreset: .high)

    private lazy var worker = CameraVisionWorker<[CanonicalRect]>(
        makeRequest: { DetectFaceRectanglesRequest() },
        map: { observations in
            observations.map { VisionGeometry.canonicalRect(for: $0) }
        },
        delivery: { [weak self] output in
            self?.faces = output.value
            self?.acceptedFrameID = output.frameID.rawValue
        }
    )

    func run() async {
        do {
            state = try await camera.start(position: .back)
            errorMessage = nil
            let camera = camera
            let worker = worker
            let consumer = Task.detached(priority: .userInitiated) {
                var iterator = camera.frameStream.frames.makeAsyncIterator()
                while !Task.isCancelled, let frame = await iterator.next() {
                    await worker.submit(frame)
                    let size = frame.geometry.pixelSize
                    await MainActor.run { [weak self] in
                        if self?.frameSize != size { self?.frameSize = size }
                    }
                }
            }
            await withTaskCancellationHandler {
                await consumer.value
            } onCancel: {
                consumer.cancel()
            }
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
        }

        await worker.invalidate()
        await camera.stop()
        if !Task.isCancelled { state = camera.currentState }
    }
}

private struct VisionLabView: View {
    @StateObject private var model = VisionLabModel()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                GeometryReader { proxy in
                    LabCameraPreview(camera: model.camera, deviceUniqueID: model.state.deviceUniqueID)
                        .background(Color.black)

                    let mapping = ViewportMapping(
                        imageSize: model.frameSize,
                        viewportSize: proxy.size,
                        contentMode: .aspectFit,
                        isMirrored: model.state.cameraPosition == .front
                    )
                    ForEach(Array(model.faces.enumerated()), id: \.offset) { _, face in
                        if let rect = mapping.viewportRect(from: face) {
                            Rectangle()
                                .stroke(Color.yellow, lineWidth: 3)
                                .frame(width: rect.width, height: rect.height)
                                .position(x: rect.midX, y: rect.midY)
                        }
                    }
                }
                .ignoresSafeArea(edges: .bottom)

                VStack(alignment: .leading, spacing: 3) {
                    Text("CameraVisionWorker / DetectFaceRectanglesRequest")
                    Text("faces \(model.faces.count) • accepted frame \(model.acceptedFrameID.map(String.init) ?? "—")")
                    if let error = model.errorMessage { Text(error).foregroundStyle(.red) }
                }
                .font(.caption2.monospaced())
                .padding(8)
                .background(Color.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(.white)
                .padding(8)
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
    let colorRotation: CGFloat
    let depthRotation: CGFloat?
    let depthDropped: Bool
}

@MainActor
private final class DepthLabModel: ObservableObject {
    @Published private(set) var state = CameraCaptureSessionState(
        isConfigured: false,
        isRunning: false,
        cameraPosition: .unspecified,
        deviceUniqueID: nil,
        deviceName: nil
    )
    @Published private(set) var snapshot: DepthSnapshot?
    @Published private(set) var errorMessage: String?
    @Published var selectedDeviceID: String?

    let devices: [CameraDeviceInfo]
    let camera = CameraCaptureSession(
        sessionPreset: .high,
        depthConfiguration: CameraDepthCaptureConfiguration()
    )

    init() {
        devices = CameraDeviceDiscovery.availableDeviceInfos().filter(\.supportsDepthData)
        selectedDeviceID = devices.first?.uniqueID
    }

    func runSelectedDevice() async {
        guard let selectedDeviceID,
              let device = devices.first(where: { $0.uniqueID == selectedDeviceID }) else {
            errorMessage = "No depth-capable camera discovered."
            return
        }

        do {
            state = try await camera.start(request: CameraDeviceRequest(device: device))
            errorMessage = nil
            guard let stream = camera.synchronizedFrameStream else { return }
            let consumer = Task.detached(priority: .userInitiated) { [weak self] in
                var iterator = stream.frames.makeAsyncIterator()
                let clock = ContinuousClock()
                var lastPublish = clock.now - .seconds(2)
                while !Task.isCancelled, let frame = await iterator.next() {
                    let now = clock.now
                    guard lastPublish.duration(to: now) >= .milliseconds(500) else { continue }
                    lastPublish = now
                    let value = Self.makeSnapshot(frame)
                    await MainActor.run { [weak self] in self?.snapshot = value }
                }
            }
            await withTaskCancellationHandler {
                await consumer.value
            } onCancel: {
                consumer.cancel()
            }
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
        }

        await camera.stop()
        if !Task.isCancelled { state = camera.currentState }
    }

    nonisolated private static func makeSnapshot(_ frame: CameraSynchronizedFrame) -> DepthSnapshot {
        let depth = frame.depth
        return DepthSnapshot(
            frameID: frame.color.id.rawValue,
            colorSize: frame.color.geometry.pixelSize,
            depthSize: depth?.geometry.pixelSize,
            centerDepthMeters: depth.flatMap(centerDepth),
            colorRotation: frame.color.geometry.appliedVideoRotationAngle,
            depthRotation: depth?.geometry.appliedVideoRotationAngle,
            depthDropped: depth == nil
        )
    }

    nonisolated private static func centerDepth(_ frame: CameraDepthFrame) -> Float? {
        let converted = frame.depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
        let map = converted.depthDataMap
        CVPixelBufferLockBaseAddress(map, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(map, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(map) else { return nil }
        let width = CVPixelBufferGetWidth(map)
        let height = CVPixelBufferGetHeight(map)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(map)
        let row = base.advanced(by: (height / 2) * bytesPerRow).assumingMemoryBound(to: Float.self)
        let value = row[width / 2]
        return value.isFinite ? value : nil
    }
}

private struct DepthLabView: View {
    @StateObject private var model = DepthLabModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("Camera", selection: $model.selectedDeviceID) {
                    ForEach(model.devices) { device in
                        Text(device.localizedName).tag(Optional(device.uniqueID))
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal)

                LabCameraPreview(camera: model.camera, deviceUniqueID: model.state.deviceUniqueID)
                    .background(Color.black)
                    .aspectRatio(4 / 3, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal)

                if let s = model.snapshot {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("RGB + DEPTH SYNCHRONIZED")
                            .fontWeight(.bold)
                        Text("frame \(s.frameID)")
                        Text("color \(Int(s.colorSize.width)) × \(Int(s.colorSize.height)) • rotation \(s.colorRotation, specifier: "%.1f")°")
                        Text("depth \(s.depthSize.map { "\(Int($0.width)) × \(Int($0.height))" } ?? "dropped") • rotation \(s.depthRotation.map { String(format: "%.1f°", $0) } ?? "—")")
                        Text("center depth \(s.centerDepthMeters.map { String(format: "%.3f m", $0) } ?? "—")")
                    }
                    .font(.caption.monospaced())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                } else {
                    Text(model.errorMessage ?? "Waiting for synchronized RGB/depth frames…")
                        .font(.caption)
                        .foregroundStyle(model.errorMessage == nil ? .secondary : .red)
                }
                Spacer()
            }
            .navigationTitle("Depth Lab")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: model.selectedDeviceID) { await model.runSelectedDevice() }
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
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("Choose Image", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(.borderedProminent)

                    if let sourceImage, let canonicalImage, let downsampledImage {
                        imageCard("Source", image: sourceImage, details: sourceDetails(sourceImage))
                        imageCard("Canonical", image: canonicalImage, details: sourceDetails(canonicalImage))
                        imageCard("Downsampled ≤ 1600 px", image: downsampledImage, details: sourceDetails(downsampledImage))
                    } else {
                        ContentUnavailableView(
                            "Select an image",
                            systemImage: "photo",
                            description: Text("Tests UIImage canonicalization and preview downsampling.")
                        )
                    }

                    if let errorMessage {
                        Text(errorMessage).font(.caption).foregroundStyle(.red)
                    }
                }
                .padding()
            }
            .navigationTitle("Image Lab")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: pickerItem) { await loadImage() }
        }
    }

    @ViewBuilder
    private func imageCard(_ title: String, image: UIImage, details: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 220)
                .frame(maxWidth: .infinity)
                .background(Color.black)
            Text(details).font(.caption2.monospaced())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sourceDetails(_ image: UIImage) -> String {
        let width = image.cgImage?.width ?? Int(image.size.width * image.scale)
        let height = image.cgImage?.height ?? Int(image.size.height * image.scale)
        return "pixels \(width) × \(height) • scale \(image.scale) • orientation \(image.imageOrientation.rawValue)"
    }

    private func loadImage() async {
        guard let pickerItem else { return }
        do {
            guard let data = try await pickerItem.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "Could not decode selected image."
                return
            }
            let canonical = image.cameraGeometryCanonicalized()
            let downsampled = canonical.cameraGeometryDownsampled(maxPixelDimension: 1600)
            sourceImage = image
            canonicalImage = canonical
            downsampledImage = downsampled
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
