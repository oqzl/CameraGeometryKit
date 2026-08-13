import Foundation

/// Thread-safe generation token used to reject results produced under obsolete
/// camera/analyzer configuration.
public final class WorkGeneration: @unchecked Sendable {
    private let lock = NSLock()
    private var value: UInt64 = 0

    public init() {}

    public var current: UInt64 {
        lock.withLock { value }
    }

    /// Advances to a new semantic configuration and returns the new generation.
    @discardableResult
    public func invalidate() -> UInt64 {
        lock.withLock {
            value &+= 1
            return value
        }
    }

    public func isCurrent(_ candidate: UInt64) -> Bool {
        lock.withLock { value == candidate }
    }
}
