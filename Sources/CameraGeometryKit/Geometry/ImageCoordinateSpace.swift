import CoreGraphics

/// Maps CameraGeometryKit's canonical source image into a cropped output image.
///
/// All pixel-space rectangles use top-left image coordinates. `cropRect` is
/// expressed in the source image's pixel coordinate system.
public struct ImageCoordinateSpace: Sendable, Hashable {
    public let sourceSize: CGSize
    public let cropRect: CGRect

    public init(sourceSize: CGSize, cropRect: CGRect) {
        self.sourceSize = sourceSize
        self.cropRect = cropRect
    }

    public static func source(size: CGSize) -> Self {
        Self(
            sourceSize: size,
            cropRect: CGRect(origin: .zero, size: size)
        )
    }

    public func canonicalPoint(fromOutputNormalized outputPoint: CGPoint) -> CanonicalPoint? {
        guard sourceSize.width > 0,
              sourceSize.height > 0,
              cropRect.width > 0,
              cropRect.height > 0 else {
            return nil
        }

        let sourcePoint = CGPoint(
            x: cropRect.minX + cropRect.width * outputPoint.x,
            y: cropRect.minY + cropRect.height * outputPoint.y
        )

        return CanonicalPoint(
            x: sourcePoint.x / sourceSize.width,
            y: sourcePoint.y / sourceSize.height
        )
    }

    /// Returns a normalized point in the cropped output image.
    ///
    /// The result can be outside 0...1 when the canonical point is outside the
    /// current crop. This is intentional; callers decide whether to clip it.
    public func outputNormalizedPoint(for canonicalPoint: CanonicalPoint) -> CGPoint? {
        guard sourceSize.width > 0,
              sourceSize.height > 0,
              cropRect.width > 0,
              cropRect.height > 0 else {
            return nil
        }

        let sourcePoint = CGPoint(
            x: canonicalPoint.x * sourceSize.width,
            y: canonicalPoint.y * sourceSize.height
        )

        return CGPoint(
            x: (sourcePoint.x - cropRect.minX) / cropRect.width,
            y: (sourcePoint.y - cropRect.minY) / cropRect.height
        )
    }

    public func canonicalRect(fromOutputNormalized outputRect: CGRect) -> CanonicalRect? {
        guard let topLeft = canonicalPoint(fromOutputNormalized: outputRect.origin),
              let bottomRight = canonicalPoint(
                fromOutputNormalized: CGPoint(x: outputRect.maxX, y: outputRect.maxY)
              ) else {
            return nil
        }

        return CanonicalRect(
            x: topLeft.x,
            y: topLeft.y,
            width: bottomRight.x - topLeft.x,
            height: bottomRight.y - topLeft.y
        )
    }

    public func outputNormalizedRect(for canonicalRect: CanonicalRect) -> CGRect? {
        guard let topLeft = outputNormalizedPoint(
            for: CanonicalPoint(x: canonicalRect.minX, y: canonicalRect.minY)
        ),
        let bottomRight = outputNormalizedPoint(
            for: CanonicalPoint(x: canonicalRect.maxX, y: canonicalRect.maxY)
        ) else {
            return nil
        }

        return CGRect(
            x: topLeft.x,
            y: topLeft.y,
            width: bottomRight.x - topLeft.x,
            height: bottomRight.y - topLeft.y
        )
    }
}
