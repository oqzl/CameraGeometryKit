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
                .tabItem { Label("Geometry", systemImage: "scope") }

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
    let videoGravity: AVLayerVideoGravity

    init(
        camera: CameraCaptureSession,
        deviceUniqueID: String?,
        videoGravity: AVLayerVideoGravity = .resizeAspect
    ) {
        self.camera = camera
        self.deviceUniqueID = deviceUniqueID
        self.videoGravity = videoGravity
    }

    func makeUIView(context: Context) -> LabPreviewContainerView {
        let view = LabPreviewContainerView()
        view.configure(
            camera: camera,
            deviceUniqueID: deviceUniqueID,
            videoGravity: videoGravity
        )
        return view
    }

    func updateUIView(_ view: LabPreviewContainerView, context: Context) {
        view.configure(
            camera: camera,
            deviceUniqueID: deviceUniqueID,
            videoGravity: videoGravity
        )
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

    func configure(
        camera: CameraCaptureSession,
        deviceUniqueID: String?,
        videoGravity: AVLayerVideoGravity
    ) {
        if previewLayer.session !== camera.captureSession {
            previewLayer.session = camera.captureSession
        }
        if previewLayer.videoGravity != videoGravity {
            previewLayer.videoGravity = videoGravity
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
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityLabel(position == .front ? "背面カメラに切り替え" : "前面カメラに切り替え")
    }
}

private struct LabHUD<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.monospaced().weight(.bold))
            content()
        }
        .font(.caption2.monospaced())
        .foregroundStyle(.white)
        .padding(8)
        .background(Color.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Geometry

@MainActor
private final class GeometryLabModel: ObservableObject {
    @Published private(set) var state = CameraCaptureSessionState(
        isConfigured: false,
        isRunning: false,
        cameraPosition: .unspecified,
        deviceUniqueID: nil,
        deviceName: nil
    )
    @Published private(set) var frameSize = CGSize.zero
    @Published private(set) var errorMessage: String?

    let camera = CameraCaptureSession(sessionPreset: .high)

    func run() async {
        do {
            state = try await camera.start(position: .back)
            errorMessage = nil
            let camera = camera
            let consumer = Task.detached(priority: .userInitiated) { [weak self] in
                var iterator = camera.frameStream.frames.makeAsyncIterator()
                var lastSize = CGSize.zero
                while !Task.isCancelled, let frame = await iterator.next() {
                    let size = frame.geometry.pixelSize
                    guard size != lastSize else { continue }
                    lastSize = size
                    await MainActor.run { [weak self] in
                        self?.frameSize = size
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
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }

        await camera.stop()
        if !Task.isCancelled { state = camera.currentState }
    }

    func switchCamera() async {
        guard state.isRunning else { return }
        do {
            let target: CameraPosition = state.cameraPosition == .front ? .back : .front
            state = try await camera.setCameraPosition(target)
            frameSize = .zero
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct GeometryLabView: View {
    @StateObject private var model = GeometryLabModel()
    @State private var contentMode: CameraContentMode = .aspectFit
    @State private var tappedCanonical: CanonicalPoint?
    @State private var lastTapWasOutside = false

    private var videoGravity: AVLayerVideoGravity {
        contentMode == .aspectFit ? .resizeAspect : .resizeAspectFill
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let mirrored = model.state.cameraPosition == .front
                let mapping = ViewportMapping(
                    imageSize: model.frameSize,
                    viewportSize: proxy.size,
                    contentMode: contentMode,
                    isMirrored: mirrored
                )

                ZStack {
                    Color.black

                    LabCameraPreview(
                        camera: model.camera,
                        deviceUniqueID: model.state.deviceUniqueID,
                        videoGravity: videoGravity
                    )

                    geometryOverlay(mapping: mapping)

                    VStack {
                        HStack(alignment: .top) {
                            LabHUD(title: "VIEWPORT → CANONICAL") {
                                Text(model.state.deviceName ?? "starting camera…")
                                Text(contentMode == .aspectFit ? "preview: aspectFit" : "preview: aspectFill")
                                Text("mirrored preview: \(mirrored ? "true" : "false")")
                                if let point = tappedCanonical {
                                    Text(String(format: "canonical: %.4f, %.4f", point.x, point.y))
                                    if let roundTrip = mapping.viewportPoint(from: point) {
                                        Text(String(format: "round trip: %.1f, %.1f pt", roundTrip.x, roundTrip.y))
                                    }
                                } else if lastTapWasOutside {
                                    Text("tap: letterbox (no image point)")
                                } else {
                                    Text("tap the preview to inspect mapping")
                                }
                                if let error = model.errorMessage {
                                    Text(error).foregroundStyle(Color.red)
                                }
                            }
                            Spacer()
                            LabCameraSwitchButton(
                                position: model.state.cameraPosition,
                                enabled: model.state.isRunning
                            ) {
                                Task { await model.switchCamera() }
                            }
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
                    }
                    .padding(10)
                }
                .contentShape(Rectangle())
                .gesture(
                    SpatialTapGesture().onEnded { value in
                        let canonical = mapping.canonicalPoint(fromViewport: value.location)
                        tappedCanonical = canonical
                        lastTapWasOutside = canonical == nil
                    }
                )
            }
            .navigationTitle("Geometry Lab")
            .navigationBarTitleDisplayMode(.inline)
            .task { await model.run() }
        }
    }

    @ViewBuilder
    private func geometryOverlay(mapping: ViewportMapping) -> some View {
        if let imageRect = mapping.imageRect {
            Rectangle()
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
                .frame(width: imageRect.width, height: imageRect.height)
                .position(x: imageRect.midX, y: imageRect.midY)
                .allowsHitTesting(false)
        }

        if let tappedCanonical,
           let point = mapping.viewportPoint(from: tappedCanonical) {
            ZStack {
                Circle().stroke(Color.cyan, lineWidth: 2).frame(width: 22, height: 22)
                Rectangle().fill(Color.cyan).frame(width: 30, height: 1)
                Rectangle().fill(Color.cyan).frame(width: 1, height: 30)
            }
            .position(point)
            .allowsHitTesting(false)
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
            let consumer = Task.detached(priority: .userInitiated) { [weak self] in
                var iterator = camera.frameStream.frames.makeAsyncIterator()
                var lastSize = CGSize.zero
                while !Task.isCancelled, let frame = await iterator.next() {
                    await worker.submit(frame)
                    let size = frame.geometry.pixelSize
                    if size != lastSize {
                        lastSize = size
                        await MainActor.run { [weak self] in self?.frameSize = size }
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
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }

        await worker.invalidate()
        await camera.stop()
        if !Task.isCancelled { state = camera.currentState }
    }

    func switchCamera() async {
        guard state.isRunning else { return }
        do {
            await worker.invalidate()
            let target: CameraPosition = state.cameraPosition == .front ? .back : .front
            state = try await camera.setCameraPosition(target)
            faces = []
            frameSize = .zero
            acceptedFrameID = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct VisionLabView: View {
    @StateObject private var model = VisionLabModel()

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let mapping = ViewportMapping(
                    imageSize: model.frameSize,
                    viewportSize: proxy.size,
                    contentMode: .aspectFit,
                    isMirrored: model.state.cameraPosition == .front
                )

                ZStack {
                    Color.black
                    LabCameraPreview(
                        camera: model.camera,
                        deviceUniqueID: model.state.deviceUniqueID
                    )

                    visionReticle
                    faceOverlay(mapping: mapping)

                    VStack {
                        HStack(alignment: .top) {
                            LabHUD(title: "VISION / FACE RECTANGLES") {
                                Text(model.state.deviceName ?? "starting camera…")
                                Text("faces: \(model.faces.count)")
                                Text("accepted frame: \(model.acceptedFrameID.map(String.init) ?? "—")")
                                Text(model.faces.isEmpty ? "scanning…" : "Vision → canonical → preview")
                                if let error = model.errorMessage {
                                    Text(error).foregroundStyle(Color.red)
                                }
                            }
                            Spacer()
                            LabCameraSwitchButton(
                                position: model.state.cameraPosition,
                                enabled: model.state.isRunning
                            ) {
                                Task { await model.switchCamera() }
                            }
                        }
                        Spacer()
                    }
                    .padding(10)
                }
            }
            .navigationTitle("Vision Lab")
            .navigationBarTitleDisplayMode(.inline)
            .task { await model.run() }
        }
    }

    private var visionReticle: some View {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [8, 8]))
            .foregroundStyle(Color.white.opacity(0.25))
            .padding(44)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private func faceOverlay(mapping: ViewportMapping) -> some View {
        ForEach(Array(model.faces.enumerated()), id: \.offset) { index, face in
            if let rect = mapping.viewportRect(from: face) {
                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .stroke(Color.yellow, lineWidth: 3)
                    Text("FACE \(index + 1)")
                        .font(.caption2.monospaced().weight(.bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.yellow)
                }
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .allowsHitTesting(false)
            }
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
    let gridColumns: Int
    let gridRows: Int
    let normalizedDepth: [Float]
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

    let devices: [CameraDeviceInfo]
    let camera = CameraCaptureSession(
        sessionPreset: .high,
        depthConfiguration: CameraDepthCaptureConfiguration(isFilteringEnabled: true)
    )

    init() {
        devices = CameraDeviceDiscovery.availableDeviceInfos().filter(\.supportsDepthData)
    }

    private var initialDevice: CameraDeviceInfo? {
        devices.first(where: { $0.position == .back }) ?? devices.first
    }

    func run() async {
        guard let initialDevice else {
            errorMessage = "No depth-capable camera discovered."
            return
        }

        do {
            state = try await camera.start(request: CameraDeviceRequest(device: initialDevice))
            errorMessage = nil
            guard let stream = camera.synchronizedFrameStream else {
                errorMessage = "Synchronized depth stream is unavailable."
                return
            }
            let consumer = Task.detached(priority: .userInitiated) { [weak self] in
                var iterator = stream.frames.makeAsyncIterator()
                let clock = ContinuousClock()
                var lastPublish = clock.now - .seconds(2)
                while !Task.isCancelled, let frame = await iterator.next() {
                    let now = clock.now
                    guard lastPublish.duration(to: now) >= .milliseconds(250) else { continue }
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
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }

        await camera.stop()
        if !Task.isCancelled { state = camera.currentState }
    }

    func switchCameraPosition() async {
        let target: CameraPosition = state.cameraPosition == .front ? .back : .front
        guard let targetDevice = devices.first(where: { $0.position == target }) else {
            errorMessage = "No depth-capable \(target.rawValue) camera is available."
            return
        }
        await selectDevice(targetDevice)
    }

    func selectDevice(_ device: CameraDeviceInfo) async {
        guard state.isRunning else { return }
        do {
            state = try await camera.setCamera(CameraDeviceRequest(device: device))
            snapshot = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var canSwitchPosition: Bool {
        let target: CameraPosition = state.cameraPosition == .front ? .back : .front
        return devices.contains(where: { $0.position == target })
    }

    nonisolated private static func makeSnapshot(_ frame: CameraSynchronizedFrame) -> DepthSnapshot {
        let depth = frame.depth
        let samples = depth.map(depthGrid) ?? (0, 0, [], nil)
        return DepthSnapshot(
            frameID: frame.color.id.rawValue,
            colorSize: frame.color.geometry.pixelSize,
            depthSize: depth?.geometry.pixelSize,
            centerDepthMeters: samples.3,
            colorRotation: frame.color.geometry.appliedVideoRotationAngle,
            depthRotation: depth?.geometry.appliedVideoRotationAngle,
            depthDropped: depth == nil,
            gridColumns: samples.0,
            gridRows: samples.1,
            normalizedDepth: samples.2
        )
    }

    nonisolated private static func depthGrid(
        _ frame: CameraDepthFrame
    ) -> (Int, Int, [Float], Float?) {
        let converted = frame.depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
        let map = converted.depthDataMap
        CVPixelBufferLockBaseAddress(map, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(map, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(map) else { return (0, 0, [], nil) }

        let width = CVPixelBufferGetWidth(map)
        let height = CVPixelBufferGetHeight(map)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(map)
        let columns = 32
        let rows = 24
        let near: Float = 0.2
        let far: Float = 5.0
        var values: [Float] = []
        values.reserveCapacity(columns * rows)

        for gridY in 0..<rows {
            let sourceY = min(height - 1, gridY * height / rows)
            let row = base
                .advanced(by: sourceY * bytesPerRow)
                .assumingMemoryBound(to: Float.self)
            for gridX in 0..<columns {
                let sourceX = min(width - 1, gridX * width / columns)
                let depth = row[sourceX]
                if depth.isFinite, depth > 0 {
                    values.append(min(1, max(0, (depth - near) / (far - near))))
                } else {
                    values.append(-1)
                }
            }
        }

        let centerRow = base
            .advanced(by: (height / 2) * bytesPerRow)
            .assumingMemoryBound(to: Float.self)
        let center = centerRow[width / 2]
        return (
            columns,
            rows,
            values,
            center.isFinite && center > 0 ? center : nil
        )
    }
}

private struct DepthLabView: View {
    @StateObject private var model = DepthLabModel()

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack {
                    Color.black
                    LabCameraPreview(
                        camera: model.camera,
                        deviceUniqueID: model.state.deviceUniqueID
                    )

                    if let snapshot = model.snapshot,
                       let depthSize = snapshot.depthSize {
                        DepthHeatmapOverlay(
                            snapshot: snapshot,
                            depthSize: depthSize,
                            viewportSize: proxy.size,
                            mirrored: model.state.cameraPosition == .front
                        )
                    }

                    depthCenterReticle

                    VStack {
                        HStack(alignment: .top) {
                            LabHUD(title: "SYNCHRONIZED DEPTH") {
                                Text(model.state.deviceName ?? "starting depth camera…")
                                if let snapshot = model.snapshot {
                                    Text("frame: \(snapshot.frameID)")
                                    Text("RGB: \(Int(snapshot.colorSize.width)) × \(Int(snapshot.colorSize.height))")
                                    Text("depth: \(snapshot.depthSize.map { "\(Int($0.width)) × \(Int($0.height))" } ?? "dropped")")
                                    Text("center: \(snapshot.centerDepthMeters.map { String(format: "%.3f m", $0) } ?? "—")")
                                    Text("rotation RGB/depth: \(String(format: "%.1f", snapshot.colorRotation))° / \(snapshot.depthRotation.map { String(format: "%.1f°", $0) } ?? "—")")
                                } else {
                                    Text("waiting for RGB + depth…")
                                }
                                if let error = model.errorMessage {
                                    Text(error).foregroundStyle(Color.red)
                                }
                            }
                            Spacer()
                            VStack(spacing: 8) {
                                LabCameraSwitchButton(
                                    position: model.state.cameraPosition,
                                    enabled: model.state.isRunning && model.canSwitchPosition
                                ) {
                                    Task { await model.switchCameraPosition() }
                                }
                                depthDeviceMenu
                            }
                        }
                        Spacer()
                    }
                    .padding(10)
                }
            }
            .navigationTitle("Depth Lab")
            .navigationBarTitleDisplayMode(.inline)
            .task { await model.run() }
        }
    }

    private var depthCenterReticle: some View {
        ZStack {
            Circle().stroke(Color.white, lineWidth: 2).frame(width: 30, height: 30)
            Rectangle().fill(Color.white).frame(width: 42, height: 1)
            Rectangle().fill(Color.white).frame(width: 1, height: 42)
        }
        .shadow(radius: 1)
        .allowsHitTesting(false)
    }

    private var depthDeviceMenu: some View {
        Menu {
            ForEach(model.devices) { device in
                Button {
                    Task { await model.selectDevice(device) }
                } label: {
                    HStack {
                        Text("\(device.position.rawValue.capitalized) · \(device.localizedName)")
                        if device.uniqueID == model.state.deviceUniqueID {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "camera.aperture")
                .font(.title3.weight(.semibold))
                .frame(width: 42, height: 42)
                .background(Color.black.opacity(0.76), in: Circle())
                .foregroundStyle(.white)
        }
    }
}

private struct DepthHeatmapOverlay: View {
    let snapshot: DepthSnapshot
    let depthSize: CGSize
    let viewportSize: CGSize
    let mirrored: Bool

    var body: some View {
        let mapping = ViewportMapping(
            imageSize: depthSize,
            viewportSize: viewportSize,
            contentMode: .aspectFit,
            isMirrored: mirrored
        )

        Canvas { context, _ in
            guard let imageRect = mapping.imageRect,
                  snapshot.gridColumns > 0,
                  snapshot.gridRows > 0,
                  snapshot.normalizedDepth.count == snapshot.gridColumns * snapshot.gridRows else {
                return
            }

            let cellWidth = imageRect.width / CGFloat(snapshot.gridColumns)
            let cellHeight = imageRect.height / CGFloat(snapshot.gridRows)
            for row in 0..<snapshot.gridRows {
                for column in 0..<snapshot.gridColumns {
                    let value = snapshot.normalizedDepth[row * snapshot.gridColumns + column]
                    guard value >= 0 else { continue }
                    let displayColumn = mirrored ? snapshot.gridColumns - 1 - column : column
                    let rect = CGRect(
                        x: imageRect.minX + CGFloat(displayColumn) * cellWidth,
                        y: imageRect.minY + CGFloat(row) * cellHeight,
                        width: cellWidth + 0.5,
                        height: cellHeight + 0.5
                    )
                    let color = Color(
                        hue: Double((1 - value) * 0.66),
                        saturation: 0.9,
                        brightness: 1,
                        opacity: 0.46
                    )
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .allowsHitTesting(false)
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
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(Color.red)
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
