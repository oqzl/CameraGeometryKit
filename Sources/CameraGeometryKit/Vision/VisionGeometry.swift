import CoreGraphics
import Vision

/// Converts Vision's normalized, bottom-left-origin geometry to and from
/// CameraGeometryKit's normalized, top-left-origin canonical image space.
public enum VisionGeometry {
    public static func canonicalPoint(fromVisionNormalized point: CGPoint) -> CanonicalPoint {
        CanonicalPoint(x: point.x, y: 1 - point.y)
    }

    public static func visionNormalizedPoint(from canonicalPoint: CanonicalPoint) -> CGPoint {
        CGPoint(x: canonicalPoint.x, y: 1 - canonicalPoint.y)
    }

    public static func canonicalRect(fromVisionNormalized rect: CGRect) -> CanonicalRect {
        CanonicalRect(
            x: rect.minX,
            y: 1 - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    public static func visionNormalizedRect(from canonicalRect: CanonicalRect) -> CGRect {
        CGRect(
            x: canonicalRect.minX,
            y: 1 - canonicalRect.maxY,
            width: canonicalRect.width,
            height: canonicalRect.height
        )
    }

    public static func canonicalRect(for observation: VNDetectedObjectObservation) -> CanonicalRect {
        canonicalRect(fromVisionNormalized: observation.boundingBox)
    }
}
