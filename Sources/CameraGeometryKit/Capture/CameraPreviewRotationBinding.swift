@preconcurrency import AVFoundation
import CoreGraphics
import Foundation

/// Keeps an `AVCaptureVideoPreviewLayer` aligned with the active camera's
/// `AVCaptureDevice.RotationCoordinator` preview angle.
///
/// The binding applies the current angle immediately and reapplies it whenever
/// AVFoundation reports a new preview angle. Apps still own preview layout and
/// `videoGravity`; CameraGeometryKit owns only the camera-specific rotation.
@MainActor
public final class CameraPreviewRotationBinding: @unchecked Sendable {
    public let device: AVCaptureDevice

    public private(set) var snapshot: CameraRotationSnapshot

    private weak var previewLayer: AVCaptureVideoPreviewLayer?
    private let rotation: CameraRotation
    private var onChange: ((CameraRotationSnapshot) -> Void)?
    private var isStopped = false

    init(device: AVCaptureDevice, previewLayer: AVCaptureVideoPreviewLayer) {
        self.device = device
        self.previewLayer = previewLayer
        rotation = CameraRotation(device: device, previewLayer: previewLayer)
        snapshot = rotation.snapshot

        applyPreviewAngle()
        rotation.observe { [weak self] snapshot in
            guard let self, !self.isStopped else { return }
            self.snapshot = snapshot
            self.applyPreviewAngle()
            self.onChange?(snapshot)
        }
    }

    /// Observe the values used by the binding, for diagnostics or UI only.
    /// Rotation application itself does not require an observer.
    public func observe(_ handler: @escaping (CameraRotationSnapshot) -> Void) {
        onChange = handler
        handler(snapshot)
    }

    /// Reapply the current preview angle.
    ///
    /// Normally unnecessary. This is available for unusual preview-layer
    /// lifecycle code where the layer's connection is recreated independently
    /// of the capture session or binding.
    public func refresh() {
        guard !isStopped else { return }
        snapshot = rotation.snapshot
        applyPreviewAngle()
        onChange?(snapshot)
    }

    public func stop() {
        guard !isStopped else { return }
        isStopped = true
        rotation.stopObserving()
        onChange = nil
    }

    private func applyPreviewAngle() {
        guard let connection = previewLayer?.connection else { return }
        rotation.applyPreviewAngle(to: connection)
    }
}

@MainActor
public extension CameraCaptureSession {
    /// Bind preview rotation to AVFoundation's camera-specific rotation source.
    ///
    /// Create a new binding after switching to a different physical camera.
    /// The returned binding must be retained for as long as automatic preview
    /// rotation should remain active.
    func bindPreviewRotation(
        to previewLayer: AVCaptureVideoPreviewLayer
    ) -> CameraPreviewRotationBinding? {
        guard let device = activeCaptureDevice else { return nil }
        return CameraPreviewRotationBinding(device: device, previewLayer: previewLayer)
    }
}
