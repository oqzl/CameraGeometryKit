import AVFoundation
import CameraGeometryKit
import SwiftUI
import UIKit

@MainActor
struct CameraSampleView: View {
    @StateObject private var model = CameraSampleModel()

    var body: some View {
        ZStack {
            CameraPreviewView(camera: model.camera)
                .background(Color.black)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                statusCard
                Spacer()
                controls
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.black)
        .task {
            await model.runSession()
        }
        .task(id: model.requestedPosition) {
            await model.switchCamera(to: model.requestedPosition)
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("CameraGeometryKit", systemImage: "camera.viewfinder")
                    .font(.headline)
                Spacer()
                Text(model.positionTitle)
                    .font(.subheadline.weight(.medium))
            }

            Text(model.state.deviceName ?? "カメラを起動しています…")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(model.frameSummary)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Text("delivered \(model.statistics.deliveredFrames)  •  dropped \(model.statistics.droppedByAVFoundation)  •  replaced \(model.statistics.replacedInLatestBuffer)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            if let errorMessage = model.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(14)
        .foregroundStyle(.primary)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var controls: some View {
        HStack {
            Text("iOS 18+ / Swift 6")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))

            Spacer()

            Button {
                model.requestedPosition = model.state.cameraPosition == .front ? .back : .front
            } label: {
                Label("切替", systemImage: "arrow.triangle.2.circlepath.camera")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(.black)
            .disabled(!model.isRunning)
        }
    }
}

private struct CameraPreviewView: UIViewRepresentable {
    let camera: CameraCaptureSession

    func makeUIView(context: Context) -> PreviewContainerView {
        PreviewContainerView()
    }

    func updateUIView(_ view: PreviewContainerView, context: Context) {
        view.update(camera: camera)
    }
}

@MainActor
private final class PreviewContainerView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    private var previewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            preconditionFailure("PreviewContainerView must use AVCaptureVideoPreviewLayer")
        }
        return layer
    }

    func update(camera: CameraCaptureSession) {
        previewLayer.session = camera.captureSession
        previewLayer.videoGravity = .resizeAspectFill
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}
