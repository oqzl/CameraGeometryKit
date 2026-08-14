import AVFoundation
import CameraGeometryKit
import SwiftUI

@MainActor
final class GeometryLabModel: ObservableObject {
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
                    await MainActor.run { [weak self] in self?.frameSize = size }
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

struct GeometryLabView: View {
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

                    VStack {
                        HStack(alignment: .top) {
                            LabHUD("VIEWPORT → CANONICAL") {
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
                                    Text("tap preview to inspect mapping")
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
}
