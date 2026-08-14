@preconcurrency import AVFoundation
import CoreMedia
import CoreVideo
import Foundation

public struct CameraFrameStreamStatistics: Sendable, Hashable {
    public let deliveredFrames: UInt64
    public let droppedByAVFoundation: UInt64
    public let replacedInLatestBuffer: UInt64

    public init(
        deliveredFrames: UInt64,
        droppedByAVFoundation: UInt64,
        replacedInLatestBuffer: UInt64
    ) {
        self.deliveredFrames = deliveredFrames
        self.droppedByAVFoundation = droppedByAVFoundation
        self.replacedInLatestBuffer = replacedInLatestBuffer
    }
}

/// `AVCaptureVideoDataOutput` wrapper with bounded, latest-frame semantics.
///
/// The AsyncStream buffer has capacity one. Consumers never accumulate an
/// unbounded queue while Vision or image processing is slower than capture.
public final class CameraFrameStream: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    public let output: AVCaptureVideoDataOutput
    public let frames: AsyncStream<CameraFrame>

    private let deliveryQueue: DispatchQueue
    private let lock = NSLock()
    private let continuation: AsyncStream<CameraFrame>.Continuation

    private var cameraPosition: CameraPosition = .unspecified
    private var sequence: UInt64 = 0
    private var deliveredFrames: UInt64 = 0
    private var droppedByAVFoundation: UInt64 = 0
    private var replacedInLatestBuffer: UInt64 = 0

    public init(
        pixelFormat: OSType? = nil,
        queueLabel: String = "net.oqzl.CameraGeometryKit.frames"
    ) {
        output = AVCaptureVideoDataOutput()
        deliveryQueue = DispatchQueue(label: queueLabel, qos: .userInitiated)

        let pair = AsyncStream<CameraFrame>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )
        frames = pair.stream
        continuation = pair.continuation

        super.init()

        output.alwaysDiscardsLateVideoFrames = true
        if let pixelFormat {
            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: pixelFormat,
            ]
        } else {
            output.videoSettings = [:]
        }
        output.setSampleBufferDelegate(self, queue: deliveryQueue)
    }

    deinit {
        continuation.finish()
    }

    public func setCameraPosition(_ position: AVCaptureDevice.Position) {
        lock.withLock {
            cameraPosition = CameraPosition(position)
        }
    }

    public func statistics() -> CameraFrameStreamStatistics {
        lock.withLock {
            CameraFrameStreamStatistics(
                deliveredFrames: deliveredFrames,
                droppedByAVFoundation: droppedByAVFoundation,
                replacedInLatestBuffer: replacedInLatestBuffer
            )
        }
    }

    func enqueueSynchronized(
        sampleBuffer: CMSampleBuffer,
        videoConnection: AVCaptureConnection,
        depthData: AVDepthData?,
        depthConnection: AVCaptureConnection?
    ) {
        enqueue(
            sampleBuffer: sampleBuffer,
            videoConnection: videoConnection,
            depthData: depthData,
            depthConnection: depthConnection
        )
    }

    func recordDroppedFrame() {
        lock.withLock {
            droppedByAVFoundation &+= 1
        }
    }

    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        enqueue(
            sampleBuffer: sampleBuffer,
            videoConnection: connection,
            depthData: nil,
            depthConnection: nil
        )
    }

    public func captureOutput(
        _ output: AVCaptureOutput,
        didDrop sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        recordDroppedFrame()
    }

    private func enqueue(
        sampleBuffer: CMSampleBuffer,
        videoConnection: AVCaptureConnection,
        depthData: AVDepthData?,
        depthConnection: AVCaptureConnection?
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        let frame: CameraFrame = lock.withLock {
            sequence &+= 1
            deliveredFrames &+= 1

            let depthFrame = depthData.map { data in
                let depthBuffer = data.depthDataMap
                return CameraDepthFrame(
                    depthData: data,
                    timestamp: timestamp,
                    geometry: CameraFrameGeometry(
                        pixelWidth: CVPixelBufferGetWidth(depthBuffer),
                        pixelHeight: CVPixelBufferGetHeight(depthBuffer),
                        cameraPosition: cameraPosition,
                        appliedVideoRotationAngle: depthConnection?.videoRotationAngle ?? videoConnection.videoRotationAngle,
                        isMirrored: depthConnection?.isVideoMirrored ?? videoConnection.isVideoMirrored
                    )
                )
            }

            return CameraFrame(
                id: CameraFrameID(rawValue: sequence),
                pixelBuffer: pixelBuffer,
                timestamp: timestamp,
                geometry: CameraFrameGeometry(
                    pixelWidth: CVPixelBufferGetWidth(pixelBuffer),
                    pixelHeight: CVPixelBufferGetHeight(pixelBuffer),
                    cameraPosition: cameraPosition,
                    appliedVideoRotationAngle: videoConnection.videoRotationAngle,
                    isMirrored: videoConnection.isVideoMirrored
                ),
                depth: depthFrame
            )
        }

        switch continuation.yield(frame) {
        case .dropped(_):
            lock.withLock {
                replacedInLatestBuffer &+= 1
            }
        case .enqueued(_), .terminated:
            break
        @unknown default:
            break
        }
    }
}
