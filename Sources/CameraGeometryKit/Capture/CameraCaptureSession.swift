@preconcurrency import AVFoundation
import Foundation
import QuartzCore

/// Thin owner of CameraGeometryKit's mutable AVFoundation capture graph.
///
/// Product UI, concrete photo settings/delegates, recording, effects, and
/// Vision model selection remain app responsibilities.
public final class CameraCaptureSession: @unchecked Sendable {
    public let captureSession: AVCaptureSession
    public let frameStream: CameraFrameStream
    public let photoOutput: AVCapturePhotoOutput

    let sessionPreset: AVCaptureSession.Preset
    let sessionQueue: DispatchQueue
    let stateLock = NSLock()

    var videoInput: AVCaptureDeviceInput?
    var activeDevice: AVCaptureDevice?
    var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    var captureRotationObservation: NSKeyValueObservation?
    var isConfigured = false
    var isRunning = false

    var activeDeviceForPreview: AVCaptureDevice?
    var stateStorage = CameraCaptureSessionState(
        isConfigured: false,
        isRunning: false,
        cameraPosition: .unspecified,
        deviceUniqueID: nil,
        deviceName: nil
    )

    public init(
        sessionPreset: AVCaptureSession.Preset = .photo,
        frameStream: CameraFrameStream = CameraFrameStream(),
        queueLabel: String = "net.oqzl.CameraGeometryKit.session"
    ) {
        captureSession = AVCaptureSession()
        photoOutput = AVCapturePhotoOutput()
        self.sessionPreset = sessionPreset
        self.frameStream = frameStream
        sessionQueue = DispatchQueue(label: queueLabel, qos: .userInitiated)
    }

    public var currentState: CameraCaptureSessionState {
        stateLock.withLock { stateStorage }
    }

    /// The preview uses its own rotation angle and coordinator. Recreate this
    /// object after a successful camera switch.
    @MainActor
    public func makePreviewRotation(previewLayer: CALayer? = nil) -> CameraRotation? {
        guard let device = stateLock.withLock({ activeDeviceForPreview }) else { return nil }
        return CameraRotation(device: device, previewLayer: previewLayer)
    }
}
