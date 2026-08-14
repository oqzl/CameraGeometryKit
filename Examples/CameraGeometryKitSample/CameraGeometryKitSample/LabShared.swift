import AVFoundation
import CameraGeometryKit
import SwiftUI
import UIKit

@MainActor
struct LabCameraPreview: UIViewRepresentable {
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
final class LabPreviewContainerView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    private var previewRotationBinding: CameraPreviewRotationBinding?
    private var observedDeviceUniqueID: String?

    private var previewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            preconditionFailure("LabPreviewContainerView requires AVCaptureVideoPreviewLayer")
        }
        return layer
    }

    func configure(camera: CameraCaptureSession, deviceUniqueID: String?, videoGravity: AVLayerVideoGravity) {
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

struct LabCameraSwitchButton: View {
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

struct LabHUD<Content: View>: View {
    let title: String
    let content: () -> Content

    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.monospaced().weight(.bold))
            content()
        }
        .font(.caption2.monospaced())
        .foregroundStyle(Color.white)
        .padding(8)
        .background(Color.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 6))
    }
}
