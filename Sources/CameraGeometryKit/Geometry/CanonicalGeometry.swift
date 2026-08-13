import CoreGraphics

/// A position in CameraGeometryKit's canonical image space.
///
/// Canonical space is normalized to the uncropped, upright, non-mirrored image:
/// - origin: top-left
/// - x: left to right
/// - y: top to bottom
/// - nominal range: 0...1
///
/// Values are not implicitly clamped. A point can intentionally remain outside
/// the unit square while mapping through a crop or viewport.
public struct CanonicalPoint: Sendable, Hashable {
    public var x: CGFloat
    public var y: CGFloat

    public init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
    }

    public init(_ point: CGPoint) {
        self.init(x: point.x, y: point.y)
    }

    public var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }

    public var isInsideUnitSquare: Bool {
        (0...1).contains(x) && (0...1).contains(y)
    }

    public func clampedToUnitSquare() -> Self {
        Self(
            x: min(1, max(0, x)),
            y: min(1, max(0, y))
        )
    }
}

/// A rectangle in CameraGeometryKit's canonical image space.
public struct CanonicalRect: Sendable, Hashable {
    public var x: CGFloat
    public var y: CGFloat
    public var width: CGFloat
    public var height: CGFloat

    public init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public init(_ rect: CGRect) {
        self.init(x: rect.origin.x, y: rect.origin.y, width: rect.width, height: rect.height)
    }

    public var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }

    public var minX: CGFloat { x }
    public var minY: CGFloat { y }
    public var maxX: CGFloat { x + width }
    public var maxY: CGFloat { y + height }

    public var center: CanonicalPoint {
        CanonicalPoint(x: x + width / 2, y: y + height / 2)
    }

    public var isInsideUnitSquare: Bool {
        minX >= 0 && minY >= 0 && maxX <= 1 && maxY <= 1
    }

    public func clampedToUnitSquare() -> Self {
        let rect = cgRect.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard !rect.isNull else {
            return Self(x: 0, y: 0, width: 0, height: 0)
        }
        return Self(rect)
    }
}
