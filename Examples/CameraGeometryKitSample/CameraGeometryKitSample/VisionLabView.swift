import CameraGeometryKit
import SwiftUI
import Vision

@MainActor
final class VisionLabModel: ObservableObject {
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

struct VisionLabView: View {
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
                    LabCameraPreview(camera: model.camera, deviceUniqueID: model.state.deviceUniqueID)

                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [8, 8]))
                        .foregroundStyle(Color.white.opacity(0.25))
                        .padding(44)
                        .allowsHitTesting(false)

                    ForEach(Array(model.faces.enumerated()), id: \.offset) { index, face in
                        if let rect = mapping.viewportRect(from: face) {
                            ZStack(alignment: .topLeading) {
                                Rectangle().stroke(Color.yellow, lineWidth: 3)
                                Text("FACE \(index + 1)")
                                    .font(.caption2.monospaced().weight(.bold))
                                    .foregroundStyle(Color.black)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.yellow)
                            }
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                            .allowsHitTesting(false)
                        }
                    }

                    VStack {
                        HStack(alignment: .top) {
                            LabHUD("VISION / FACE RECTANGLES") {
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
}
