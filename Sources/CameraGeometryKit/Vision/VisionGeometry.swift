import Vision

/// Converts Vision's Swift-native normalized geometry to and from
/// CameraGeometryKit's normalized, top-left-origin canonical image space.
public enum VisionGeometry {
    public static func canonicalPoint(from point: NormalizedPoint) -> CanonicalPoint {
        CanonicalPoint(x: point.x, y: 1 - point.y)
    }

    public static func normalizedPoint(from canonicalPoint: CanonicalPoint) -> NormalizedPoint {
        NormalizedPoint(x: canonicalPoint.x, y: 1 - canonicalPoint.y)
    }

    public static func canonicalRect(from rect: NormalizedRect) -> CanonicalRect {
        CanonicalRect(
            x: rect.origin.x,
            y: 1 - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    public static func normalizedRect(from canonicalRect: CanonicalRect) -> NormalizedRect {
        NormalizedRect(
            x: canonicalRect.minX,
            y: 1 - canonicalRect.maxY,
            width: canonicalRect.width,
            height: canonicalRect.height
        )
    }

    public static func canonicalRect(for observation: any BoundingBoxProviding) -> CanonicalRect {
        canonicalRect(from: observation.boundingBox)
    }
}
