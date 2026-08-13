@preconcurrency import AVFoundation
import CoreGraphics

/// AVFoundation's normalized capture-device point-of-interest coordinate.
///
/// This is intentionally a different type from `CanonicalPoint`. It represents
/// the unrotated capture-device picture area and is suitable for focus/exposure
/// APIs. Keeping the types separate prevents accidental mixing with upright
/// canonical image-space coordinates.
public struct CaptureDevicePoint: Sendable, Hashable {
    public let x: CGFloat
    public let y: CGFloat

    public init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
    }

    public var cgPoint: CGPoint { CGPoint(x: x, y: y) }
}

@MainActor
public extension AVCaptureVideoPreviewLayer {
    /// Converts a preview-layer touch to AVFoundation's focus/exposure space.
    /// AVFoundation accounts for the layer size and `videoGravity`.
    func captureDevicePoint(fromLayerPoint point: CGPoint) -> CaptureDevicePoint {
        CaptureDevicePoint(captureDevicePointConverted(fromLayerPoint: point))
    }

    /// Converts AVFoundation's focus/exposure point back to preview-layer space.
    func layerPoint(fromCaptureDevicePoint point: CaptureDevicePoint) -> CGPoint {
        layerPointConverted(fromCaptureDevicePoint: point.cgPoint)
    }
}

private extension CaptureDevicePoint {
    init(_ point: CGPoint) {
        self.init(x: point.x, y: point.y)
    }
}
