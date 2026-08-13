import Foundation

/// Preferred high-level Vision worker.
///
/// `CameraVisionPipeline` owns request execution, bounded latest-frame
/// scheduling, and active-request cancellation. This wrapper adds a second
/// generation gate at the actual MainActor delivery point so an invalidation
/// cannot race with a result that was already queued for UI publication.
public final class CameraVisionWorker<Value: Sendable>: @unchecked Sendable {
    public typealias MakeRequest = CameraVisionPipeline<Value>.MakeRequest
    public typealias Extract = CameraVisionPipeline<Value>.Extract
    public typealias Delivery = CameraVisionPipeline<Value>.Delivery

    private let generation: WorkGeneration
    private let pipeline: CameraVisionPipeline<Value>

    public init(
        queueLabel: String = "net.oqzl.CameraGeometryKit.vision",
        makeRequest: @escaping MakeRequest,
        extract: @escaping Extract,
        delivery: @escaping Delivery
    ) {
        let generation = WorkGeneration()
        self.generation = generation
        pipeline = CameraVisionPipeline(
            queueLabel: queueLabel,
            makeRequest: makeRequest,
            extract: extract
        ) { output in
            guard generation.isCurrent(output.generation) else { return }
            delivery(output)
        }
    }

    public func submit(_ frame: CameraFrame) {
        pipeline.submit(frame)
    }

    /// Invalidates semantic work first, then asks the underlying Vision
    /// pipeline to clear pending work and stop the active request.
    public func invalidate() {
        generation.invalidate()
        pipeline.invalidate()
    }

    public var currentGeneration: UInt64 {
        generation.current
    }
}
