@preconcurrency import AVFoundation
import CoreMedia
import CoreVideo
import Foundation

public final class CameraDepthDelivery: NSObject, @unchecked Sendable {
    let videoOutput: AVCaptureVideoDataOutput
    let depthOutput: AVCaptureDepthDataOutput
    public let frames: AsyncStream<CameraSynchronizedFrame>

    let callbackQueue: DispatchQueue
    var synchronizer: AVCaptureDataOutputSynchronizer?

    private let lock = NSLock()
    private let continuation: AsyncStream<CameraSynchronizedFrame>.Continuation
    private var cameraPosition: CameraPosition = .unspecified
    private var sequence: UInt64 = 0

    init(
        configuration: CameraDepthCaptureConfiguration,
        queueLabel: String = "net.oqzl.CameraGeometryKit.depth-frames"
    ) {
        videoOutput = AVCaptureVideoDataOutput()
        depthOutput = AVCaptureDepthDataOutput()
        callbackQueue = DispatchQueue(label: queueLabel, qos: .userInitiated)
        let pair = AsyncStream<CameraSynchronizedFrame>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )
        frames = pair.stream
        continuation = pair.continuation
        super.init()

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [:]
        depthOutput.alwaysDiscardsLateDepthData = true
        depthOutput.isFilteringEnabled = configuration.isFilteringEnabled
    }

    deinit {
        continuation.finish()
    }

    func setCameraPosition(_ position: AVCaptureDevice.Position) {
        lock.withLock {
            cameraPosition = CameraPosition(position)
        }
    }

    public func dataOutputSynchronizer(
        _ synchronizer: AVCaptureDataOutputSynchronizer,
        didOutput collection: AVCaptureSynchronizedDataCollection
    ) {
        guard let video = collection.synchronizedData(for: videoOutput)
            as? AVCaptureSynchronizedSampleBufferData,
            !video.sampleBufferWasDropped,
            let connection = videoOutput.connection(with: .video),
            let color = makeColorFrame(video.sampleBuffer, connection: connection)
        else { return }

        let depthSample = collection.synchronizedData(for: depthOutput)
            as? AVCaptureSynchronizedDepthData
        continuation.yield(
            CameraSynchronizedFrame(
                color: color,
                depth: makeDepthFrame(depthSample, color: color)
            )
        )
    }

    private func makeColorFrame(
        _ sampleBuffer: CMSampleBuffer,
        connection: AVCaptureConnection
    ) -> CameraFrame? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        return lock.withLock {
            sequence &+= 1
            return CameraFrame(
                id: CameraFrameID(rawValue: sequence),
                pixelBuffer: pixelBuffer,
                timestamp: CMSampleBufferGetPresentationTimeStamp(sampleBuffer),
                geometry: CameraFrameGeometry(
                    pixelWidth: CVPixelBufferGetWidth(pixelBuffer),
                    pixelHeight: CVPixelBufferGetHeight(pixelBuffer),
                    cameraPosition: cameraPosition,
                    appliedVideoRotationAngle: connection.videoRotationAngle,
                    isMirrored: connection.isVideoMirrored
                )
            )
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

public typealias CameraSynchronizedFrameStream = CameraDepthDelivery
