import CoreMedia
import Foundation
import Vision

public struct CameraVisionOutput<Value: Sendable>: Sendable {
    public let frameID: CameraFrameID
    public let timestamp: CMTime
    public let generation: UInt64
    public let value: Value

    public init(
        frameID: CameraFrameID,
        timestamp: CMTime,
        generation: UInt64,
        value: Value
    ) {
        self.frameID = frameID
        self.timestamp = timestamp
        self.generation = generation
        self.value = value
    }
}

@MainActor
private final class CameraVisionDeliveryGate<Value: Sendable> {
    private var generation: UInt64 = 0

    nonisolated init() {}

    func invalidate(to generation: UInt64) {
        self.generation = generation
    }

    func deliver(
        _ output: CameraVisionOutput<Value>,
        using delivery: @MainActor @Sendable (CameraVisionOutput<Value>) -> Void
    ) {
        guard output.generation == generation else { return }
        delivery(output)
    }
}

/// Swift 6 / iOS 18+ live Vision worker.
///
/// The worker uses Vision's Swift-native async API. It keeps one expensive
/// operation in flight, retains only the newest pending frame, and rejects
/// obsolete results after invalidation.
public actor CameraVisionWorker<Value: Sendable> {
    public typealias Operation = @Sendable (CameraFrame) async throws -> Value
    public typealias Delivery = @MainActor @Sendable (CameraVisionOutput<Value>) -> Void

    private let operation: Operation
    private let delivery: Delivery
    private let deliveryGate = CameraVisionDeliveryGate<Value>()

    private var generation: UInt64 = 0
    private var pendingFrame: CameraFrame?
    private var loopTask: Task<Void, Never>?
    private var operationTask: Task<Value, any Error>?

    public init(
        operation: @escaping Operation,
        delivery: @escaping Delivery
    ) {
        self.operation = operation
        self.delivery = delivery
    }

    /// Creates a worker for one Swift-native Vision `ImageProcessingRequest`.
    /// A fresh request value is created for each accepted frame.
    public init<Request: ImageProcessingRequest>(
        makeRequest: @escaping @Sendable () -> Request,
        map: @escaping @Sendable (Request.Result) throws -> Value,
        delivery: @escaping Delivery
    ) {
        self.operation = { frame in
            let request = makeRequest()
            let result = try await request.perform(
                on: frame.pixelBuffer,
                orientation: frame.geometry.visionOrientation
            )
            return try map(result)
        }
        self.delivery = delivery
    }

    public var currentGeneration: UInt64 {
        generation
    }

    /// If analysis is already running, this replaces the previous pending frame
    /// instead of growing a queue.
    public func submit(_ frame: CameraFrame) {
        pendingFrame = frame
        startLoopIfNeeded()
    }

    /// Invalidates old semantic work and requests cooperative Task cancellation.
    /// Generation identity remains the correctness guarantee even if the
    /// underlying operation cannot stop immediately.
    public func invalidate() async {
        generation &+= 1
        pendingFrame = nil
        operationTask?.cancel()
        await deliveryGate.invalidate(to: generation)
    }

    private func startLoopIfNeeded() {
        guard loopTask == nil else { return }
        loopTask = Task { [weak self] in
            await self?.drain()
        }
    }

    private func drain() async {
        defer {
            loopTask = nil
            if pendingFrame != nil {
                startLoopIfNeeded()
            }
        }

        while let frame = takePendingFrame() {
            let workGeneration = generation
            let operation = self.operation
            let task = Task {
                try await operation(frame)
            }
            operationTask = task

            do {
                let value = try await task.value
                operationTask = nil

                guard generation == workGeneration else { continue }

                let output = CameraVisionOutput(
                    frameID: frame.id,
                    timestamp: frame.timestamp,
                    generation: workGeneration,
                    value: value
                )
                await deliveryGate.deliver(output, using: delivery)
            } catch is CancellationError {
                operationTask = nil
            } catch {
                operationTask = nil
            }
        }
    }

    private func takePendingFrame() -> CameraFrame? {
        defer { pendingFrame = nil }
        return pendingFrame
    }
}
