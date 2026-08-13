@preconcurrency import AVFoundation
import CoreGraphics
import Foundation
import QuartzCore

public struct CameraRotationSnapshot: Sendable, Hashable {
    public let previewAngle: CGFloat
    public let captureAngle: CGFloat

    public init(previewAngle: CGFloat, captureAngle: CGFloat) {
        self.previewAngle = previewAngle
        self.captureAngle = captureAngle
    }
}

/// Resolves camera-specific rotation using `AVCaptureDevice.RotationCoordinator`.
///
/// Do not derive these angles from interface orientation, device model, front /
/// back position, or pixel-buffer dimensions.
@MainActor
public final class CameraRotation {
    public let device: AVCaptureDevice
    public let coordinator: AVCaptureDevice.RotationCoordinator

    private var previewObservation: NSKeyValueObservation?
    private var captureObservation: NSKeyValueObservation?
    private var onChange: ((CameraRotationSnapshot) -> Void)?

    public init(device: AVCaptureDevice, previewLayer: CALayer? = nil) {
        self.device = device
        coordinator = AVCaptureDevice.RotationCoordinator(
            device: device,
            previewLayer: previewLayer
        )
    }

    public var snapshot: CameraRotationSnapshot {
        CameraRotationSnapshot(
            previewAngle: coordinator.videoRotationAngleForHorizonLevelPreview,
            captureAngle: coordinator.videoRotationAngleForHorizonLevelCapture
        )
    }

    /// Observe both preview and capture angles. AVFoundation documents these KVO
    /// notifications as arriving on the main queue.
    public func observe(_ handler: @escaping (CameraRotationSnapshot) -> Void) {
        onChange = handler

        previewObservation = coordinator.observe(
            \.videoRotationAngleForHorizonLevelPreview,
            options: [.initial, .new]
        ) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.publishSnapshot()
            }
        }

        captureObservation = coordinator.observe(
            \.videoRotationAngleForHorizonLevelCapture,
            options: [.new]
        ) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.publishSnapshot()
            }
        }
    }

    public func stopObserving() {
        previewObservation = nil
        captureObservation = nil
        onChange = nil
    }

    /// Apply the preview angle to a preview connection.
    public func applyPreviewAngle(to connection: AVCaptureConnection) {
        let angle = coordinator.videoRotationAngleForHorizonLevelPreview
        guard connection.isVideoRotationAngleSupported(angle) else { return }
        connection.videoRotationAngle = angle
    }

    /// Apply the capture angle to a photo, movie, or analysis connection.
    ///
    /// For `AVCaptureVideoDataOutput + AVAssetWriter` recording, prefer leaving
    /// the data-output connection unrotated and encode orientation with
    /// `AVAssetWriterInput.transform` instead. See the rotation documentation.
    public func applyCaptureAngle(to connection: AVCaptureConnection) {
        let angle = coordinator.videoRotationAngleForHorizonLevelCapture
        guard connection.isVideoRotationAngleSupported(angle) else { return }
        connection.videoRotationAngle = angle
    }

    private func publishSnapshot() {
        onChange?(snapshot)
    }
}
