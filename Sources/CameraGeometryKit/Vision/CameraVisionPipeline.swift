@preconcurrency import Vision
import CoreMedia
import Foundation

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

/// A bounded Vision worker for live camera frames.
///
/// Semantics:
/// - one Vision request is in flight at a time;
/// - while it runs, only the newest pending frame is retained;
/// - `invalidate()` cancels the current request, clears pending work, and bumps
///   the generation so stale results can never publish;
/// - results are mapped to a Sendable value before crossing back to MainActor.
///
/// This design intentionally does not cancel an in-flight request merely because
/// a newer frame arrives; doing that at camera frame rates can prevent expensive
/// requests from ever completing.
public final class CameraVisionPipeline<Value: Sendable>: @unchecked Sendable {
    public typealias MakeRequest = @Sendable () -> VNRequest
    public typealias Extract = @Sendable (VNRequest) throws -> Value
    public typealias Delivery = @MainActor @Sendable (CameraVisionOutput<Value>) -> Void

    private let makeRequest: MakeRequest
    private let extract: Extract
    private let delivery: Delivery
    private let queue: DispatchQueue
    private let lock = NSLock()

    private var pendingFrame: CameraFrame?
    private var isWorkerScheduled = false
    private var generation: UInt64 = 0
    private var currentRequest: VNRequest?

    public init(
        queueLabel: String = "net.oqzl.CameraGeometryKit.vision",
        makeRequest: @escaping MakeRequest,
        extract: @escaping Extract,
        delivery: @escaping Delivery
    ) {
        self.makeRequest = makeRequest
        self.extract = extract
        self.delivery = delivery
        queue = DispatchQueue(label: queueLabel, qos: .userInitiated)
    }

    /// Submit a camera frame. If Vision is busy, this replaces the previously
    /// pending frame instead of creating a backlog.
    public func submit(_ frame: CameraFrame) {
        let shouldSchedule: Bool = lock.withLock {
            pendingFrame = frame
            guard !isWorkerScheduled else { return false }
            isWorkerScheduled = true
            return true
        }

        guard shouldSchedule else { return }
        queue.async { [weak self] in
            self?.drain()
        }
    }

    /// Cancel old work after a configuration change, camera switch, or screen
    /// departure. A fresh submission after this call belongs to a new generation.
    public func invalidate() {
        lock.withLock {
            generation &+= 1
            pendingFrame = nil
            currentRequest?.cancel()
        }
    }

    public var currentGeneration: UInt64 {
        lock.withLock { generation }
    }

    private func drain() {
        while true {
            let work: (CameraFrame, UInt64)? = lock.withLock {
                guard let pendingFrame else {
                    isWorkerScheduled = false
                    return nil
                }
                self.pendingFrame = nil
                return (pendingFrame, generation)
            }

            guard let (frame, workGeneration) = work else { return }

            autoreleasepool {
                let request = makeRequest()
                lock.withLock {
                    currentRequest = request
                }

                let handler = VNImageRequestHandler(
                    cvPixelBuffer: frame.pixelBuffer,
                    orientation: frame.geometry.visionOrientation,
                    options: [:]
                )

                do {
                    try handler.perform([request])
                    let value = try extract(request)

                    let shouldPublish = lock.withLock {
                        currentRequest = nil
                        return generation == workGeneration
                    }

                    guard shouldPublish else { return }
                    let output = CameraVisionOutput(
                        frameID: frame.id,
                        timestamp: frame.timestamp,
                        generation: workGeneration,
                        value: value
                    )

                    Task { @MainActor [delivery] in
                        delivery(output)
                    }
                } catch {
                    lock.withLock {
                        if currentRequest === request {
                            currentRequest = nil
                        }
                    }
                    // Cancellation and request-specific errors are deliberately
                    // not published as UI state. Apps may wrap `extract` if they
                    // need domain-specific error reporting.
                }
            }
        }
    }
}
