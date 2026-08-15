@preconcurrency import AVFoundation
import CoreMedia
import CoreVideo
import Foundation

public struct CameraSynchronizedFrameStreamStatistics: Sendable, Hashable {
    public let deliveredFrames: UInt64
    public let droppedColorByAVFoundation: UInt64
    public let droppedDepthByAVFoundation: UInt64
    public let replacedInLatestBuffer: UInt64

    public init(
        deliveredFrames: UInt64,
        droppedColorByAVFoundation: UInt64,
        droppedDepthByAVFoundation: UInt64,
        replacedInLatestBuffer: UInt64
    ) {
        self.deliveredFrames = deliveredFrames
        self.droppedColorByAVFoundation = droppedColorByAVFoundation
        self.droppedDepthByAVFoundation = droppedDepthByAVFoundation
        self.replacedInLatestBuffer = replacedInLatestBuffer
    }
}

/// Time-matched color/depth delivery backed by `AVCaptureDataOutputSynchronizer`.
///
/// Color frames are also emitted through the session's `CameraFrameStream`, so
/// enabling depth does not create a dead color-only frame source or a second
/// color-output configuration.
public final class CameraSynchronizedFrameStream: NSObject, @unchecked Sendable {
    let frameStream: CameraFrameStream
    let depthOutput: AVCaptureDepthDataOutput
    public let frames: AsyncStream<CameraSynchronizedFrame>

    var videoOutput: AVCaptureVideoDataOutput { frameStream.output }
    let callbackQueue: DispatchQueue
    var synchronizer: AVCaptureDataOutputSynchronizer?

    private let lock = NSLock()
    private let continuation: AsyncStream<CameraSynchronizedFrame>.Continuation
    private var deliveredFrames: UInt64 = 0
    private var droppedColorByAVFoundation: UInt64 = 0
    private var droppedDepthByAVFoundation: UInt64 = 0
    private var replacedInLatestBuffer: UInt64 = 0

    init(
        configuration: CameraDepthCaptureConfiguration,
        frameStream: CameraFrameStream,
        queueLabel: String = "net.oqzl.CameraGeometryKit.depth-frames"
    ) {
        self.frameStream = frameStream
        depthOutput = AVCaptureDepthDataOutput()
        callbackQueue = DispatchQueue(label: queueLabel, qos: .userInitiated)

        let pair = AsyncStream<CameraSynchronizedFrame>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )
        frames = pair.stream
        continuation = pair.continuation

        super.init()

        frameStream.useSynchronizedDelivery()
        depthOutput.alwaysDiscardsLateDepthData = true
        depthOutput.isFilteringEnabled = configuration.isFilteringEnabled
    }

    deinit {
        continuation.finish()
    }

    func setCameraPosition(_ position: AVCaptureDevice.Position) {
        frameStream.setCameraPosition(position)
    }

    public func statistics() -> CameraSynchronizedFrameStreamStatistics {
        lock.withLock {
            CameraSynchronizedFrameStreamStatistics(
                deliveredFrames: deliveredFrames,
                droppedColorByAVFoundation: droppedColorByAVFoundation,
                droppedDepthByAVFoundation: droppedDepthByAVFoundation,
                replacedInLatestBuffer: replacedInLatestBuffer
            )
        }
    }

    public func dataOutputSynchronizer(
        _ synchronizer: AVCaptureDataOutputSynchronizer,
        didOutput collection: AVCaptureSynchronizedDataCollection
    ) {
        guard let video = collection.synchronizedData(for: videoOutput)
            as? AVCaptureSynchronizedSampleBufferData
        else { return }

        if video.sampleBufferWasDropped {
            frameStream.recordSynchronizedDrop()
            lock.withLock {
                droppedColorByAVFoundation &+= 1
            }
            return
        }

        guard let connection = videoOutput.connection(with: .video),
              let color = frameStream.deliverSynchronized(
                video.sampleBuffer,
                connection: connection
              )
        else { return }

        let depthSample = collection.synchronizedData(for: depthOutput)
            as? AVCaptureSynchronizedDepthData
        let depth = makeDepthFrame(depthSample, color: color)

        lock.withLock {
            deliveredFrames &+= 1
            if depthSample == nil || depthSample?.depthDataWasDropped == true {
                droppedDepthByAVFoundation &+= 1
            }
        }

        switch continuation.yield(
            CameraSynchronizedFrame(color: color, depth: depth)
        ) {
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

    private func makeDepthFrame(
        _ sample: AVCaptureSynchronizedDepthData?,
        color: CameraFrame
    ) -> CameraDepthFrame? {
        guard let sample, !sample.depthDataWasDropped else { return nil }
        let data = sample.depthData
        let map = data.depthDataMap
        let connection = depthOutput.connection(with: .depthData)

        return CameraDepthFrame(
            depthData: data,
            timestamp: sample.timestamp,
            geometry: CameraDepthFrameGeometry(
                pixelWidth: CVPixelBufferGetWidth(map),
                pixelHeight: CVPixelBufferGetHeight(map),
                cameraPosition: color.geometry.cameraPosition,
                appliedVideoRotationAngle: connection?.videoRotationAngle
                    ?? color.geometry.appliedVideoRotationAngle,
                isMirrored: connection?.isVideoMirrored ?? color.geometry.isMirrored,
                depthDataType: data.depthDataType,
                isFiltered: data.isDepthDataFiltered
            )
        )
    }
}
