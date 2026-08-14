@preconcurrency import AVFoundation
import Foundation

final class CameraDepthSynchronizer: NSObject, CameraDataOutputSynchronizerDelegate, @unchecked Sendable {
    let depthOutput: AVCaptureDepthDataOutput
    private let frameStream: CameraFrameStream
    private let synchronizer: AVCaptureDataOutputSynchronizer
    private let callbackQueue: DispatchQueue

    init(frameStream: CameraFrameStream, configuration: CameraDepthConfiguration) {
        self.frameStream = frameStream
        depthOutput = AVCaptureDepthDataOutput()
        depthOutput.alwaysDiscardsLateDepthData = true
        depthOutput.isFilteringEnabled = configuration.isFilteringEnabled
        callbackQueue = DispatchQueue(label: "net.oqzl.CameraGeometryKit.depth-sync", qos: .userInitiated)
        synchronizer = AVCaptureDataOutputSynchronizer(dataOutputs: [frameStream.output, depthOutput])
        super.init()
        synchronizer.setDelegate(self, queue: callbackQueue)
    }

    func dataOutputSynchronizer(
        _ synchronizer: AVCaptureDataOutputSynchronizer,
        didOutput collection: AVCaptureSynchronizedDataCollection
    ) {
        guard let video = collection.synchronizedData(for: frameStream.output)
            as? AVCaptureSynchronizedSampleBufferData else { return }
        guard !video.sampleBufferWasDropped else {
            frameStream.recordDroppedFrame()
            return
        }
        guard let videoConnection = frameStream.output.connection(with: .video) else { return }

        let syncedDepth = collection.synchronizedData(for: depthOutput)
            as? AVCaptureSynchronizedDepthData
        let depthData: AVDepthData?
        if let syncedDepth, !syncedDepth.depthDataWasDropped {
            depthData = syncedDepth.depthData
        } else {
            depthData = nil
        }

        frameStream.enqueueSynchronized(
            sampleBuffer: video.sampleBuffer,
            videoConnection: videoConnection,
            depthData: depthData,
            depthConnection: depthOutput.connection(with: .depthData)
        )
    }
}
