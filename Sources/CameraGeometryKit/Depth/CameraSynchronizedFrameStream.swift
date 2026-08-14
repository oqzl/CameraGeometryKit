@preconcurrency import AVFoundation
import Foundation

public final class CameraDepthDelivery: NSObject, @unchecked Sendable {
    let videoOutput: AVCaptureVideoDataOutput
    let depthOutput: AVCaptureDepthDataOutput
    public let frames: AsyncStream<CameraSynchronizedFrame>

    let callbackQueue: DispatchQueue
    let lock = NSLock()
    let continuation: AsyncStream<CameraSynchronizedFrame>.Continuation
    var synchronizer: AVCaptureDataOutputSynchronizer?
    var cameraPosition: CameraPosition = .unspecified
    var sequence: UInt64 = 0

    init(
        configuration: CameraDepthCaptureConfiguration,
        queueLabel: String = "net.oqzl.CameraGeometryKit.depth-frames"
    ) {
        videoOutput = AVCaptureVideoDataOutput()
        depthOutput = AVCaptureDepthDataOutput()
        callbackQueue = DispatchQueue(label: queueLabel, qos: .userInitiated)
        let pair = AsyncStream<CameraSynchronizedFrame>.makeStream(bufferingPolicy: .bufferingNewest(1))
        frames = pair.stream
        continuation = pair.continuation
        super.init()
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [:]
        depthOutput.alwaysDiscardsLateDepthData = true
        depthOutput.isFilteringEnabled = configuration.isFilteringEnabled
    }

    deinit { continuation.finish() }
}
