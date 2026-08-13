@preconcurrency import AVFoundation

/// Common connection policies that keep rotation and mirroring as independent
/// concerns.
public enum CameraConnectionConfiguration {
    /// Canonical analysis frames are non-mirrored. Front-camera mirroring is a
    /// presentation policy, not an image-space identity.
    public static func configureCanonicalAnalysisMirroring(
        on connection: AVCaptureConnection
    ) {
        guard connection.isVideoMirroringSupported else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = false
    }

    /// Typical preview policy: front camera mirrored, back camera not mirrored.
    public static func configurePreviewMirroring(
        on connection: AVCaptureConnection,
        cameraPosition: AVCaptureDevice.Position
    ) {
        guard connection.isVideoMirroringSupported else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = cameraPosition == .front
    }
}
