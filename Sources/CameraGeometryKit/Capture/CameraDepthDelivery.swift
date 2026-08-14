@preconcurrency import AVFoundation
import Foundation

final class CameraDepthDelivery: NSObject, @unchecked Sendable {
    private let frameStream: CameraFrameStream
    private let depthOutput: AVCaptureDepthDataOutput
    private let synchronizer: AVCaptureDataOutputSynchronizer
    private let callbackQueue: DispatchQueue

    init(frameStream: CameraFrameStream, depthOutput: AVCaptureDepthDataOutput) {
        self.frameStream = frameStream
        self.depthOutput = depthOutput
        callbackQueue = DispatchQueue(
            label: "net.oqzl.CameraGeometryKit.depth-sync",
            qos: .userInitiated
        )
        synchronizer = AVCaptureDataOutputSynchronizer(
            dataOutputs: [frameStream.output, depthOutput]
        )
        super.init()
    }

    func start() {
        synchronizer.setDelegate(self, queue: callbackQueue)
    }

    func dataOutputSynchronizer(
        _ synchronizer: AVCaptureDataOutputSynchronizer,
        didOutput collection: AVCaptureSynchronizedDataCollection
    ) {
        guard let video = collection.synchronizedData(for: frameStream.output)
            as? AVCaptureSynchronizedSampleBufferData else { return }
        if video.sampleBufferWasDropped {
            frameStream.recordDroppedFrame()
            return
        }
        guard let connection = frameStream.output.connection(with: .video) else { return }

        let item = collection.synchronizedData(for: depthOutput)
            as? AVCaptureSynchronizedDepthData
        let depth = item.flatMap {
            $0.depthDataWasDropped ? nil : $0.depthData
        }

        frameStream.enqueueSynchronized(
            sampleBuffer: video.sampleBuffer,
            videoConnection: connection,
            depthData: depth,
            depthConnection: depthOutput.connection(with: .depthData)
        )
    }
}
