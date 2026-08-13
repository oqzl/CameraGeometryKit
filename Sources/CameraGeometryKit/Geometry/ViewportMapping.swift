import CoreGraphics

public enum CameraContentMode: Sendable, Hashable {
    case aspectFit
    case aspectFill
}

/// Maps an already-upright image between canonical coordinates and a display
/// viewport. This type is for image/frame rendering, not for guessing sensor
/// orientation from view geometry.
public struct ViewportMapping: Sendable, Hashable {
    public let imageSize: CGSize
    public let viewportSize: CGSize
    public let contentMode: CameraContentMode
    public let isMirrored: Bool

    public init(
        imageSize: CGSize,
        viewportSize: CGSize,
        contentMode: CameraContentMode,
        isMirrored: Bool = false
    ) {
        self.imageSize = imageSize
        self.viewportSize = viewportSize
        self.contentMode = contentMode
        self.isMirrored = isMirrored
    }

    public var imageRect: CGRect? {
        guard imageSize.width > 0,
              imageSize.height > 0,
              viewportSize.width > 0,
              viewportSize.height > 0 else {
            return nil
        }

        let widthScale = viewportSize.width / imageSize.width
        let heightScale = viewportSize.height / imageSize.height
        let scale: CGFloat

        switch contentMode {
        case .aspectFit:
            scale = min(widthScale, heightScale)
        case .aspectFill:
            scale = max(widthScale, heightScale)
        }

        let size = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )

        return CGRect(
            x: (viewportSize.width - size.width) / 2,
            y: (viewportSize.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    /// Converts a viewport point to canonical image space.
    ///
    /// For aspect-fit previews, points in the letterbox return `nil`. For
    /// aspect-fill previews, the viewport always lies inside the rendered image.
    public func canonicalPoint(fromViewport point: CGPoint) -> CanonicalPoint? {
        guard let imageRect else { return nil }
        if contentMode == .aspectFit, !imageRect.contains(point) {
            return nil
        }

        var x = (point.x - imageRect.minX) / imageRect.width
        let y = (point.y - imageRect.minY) / imageRect.height

        if isMirrored {
            x = 1 - x
        }

        return CanonicalPoint(x: x, y: y)
    }

    public func viewportPoint(from canonicalPoint: CanonicalPoint) -> CGPoint? {
        guard let imageRect else { return nil }

        let x = isMirrored ? 1 - canonicalPoint.x : canonicalPoint.x
        return CGPoint(
            x: imageRect.minX + imageRect.width * x,
            y: imageRect.minY + imageRect.height * canonicalPoint.y
        )
    }

    public func viewportRect(from canonicalRect: CanonicalRect) -> CGRect? {
        guard let p0 = viewportPoint(
            from: CanonicalPoint(x: canonicalRect.minX, y: canonicalRect.minY)
        ),
        let p1 = viewportPoint(
            from: CanonicalPoint(x: canonicalRect.maxX, y: canonicalRect.maxY)
        ) else {
            return nil
        }

        return CGRect(
            x: min(p0.x, p1.x),
            y: min(p0.y, p1.y),
            width: abs(p1.x - p0.x),
            height: abs(p1.y - p0.y)
        )
    }
}
