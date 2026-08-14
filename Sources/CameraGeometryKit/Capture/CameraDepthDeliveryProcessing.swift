@preconcurrency import AVFoundation

extension CameraDepthDelivery {
    func start() {
        synchronizer.setDelegate(self, queue: callbackQueue)
    }

    func deliver(_ collection: AVCaptureSynchronizedDataCollection) {
        guard let video = collection.synchronizedData(for: frameStream.output)
            as? AVCaptureSynchronizedSampleBufferData else { return }
        if video.sampleBufferWasDropped {
            frameStream.recordDroppedFrame()
            return
        }
        guard let connection = frameStream.output.connection(with: .video) else { return }

        let item = collection.synchronizedData(for: depthOutput) as? AVCaptureSynchronizedDepthData
        let depth = item.flatMap { $0.depthDataWasDropped ? nil : $0.depthData }

        frameStream.enqueueSynchronized(
            sampleBuffer: video.sampleBuffer,
            videoConnection: connection,
            depthData: depth,
            depthConnection: depthOutput.connection(with: .depthData)
        )
    }
}
