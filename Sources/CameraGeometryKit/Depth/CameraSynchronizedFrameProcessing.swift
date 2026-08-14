import AVFoundation

extension CameraDepthDelivery {
    func dataOutputSynchronizer(
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
        let depth = makeDepthFrame(depthSample, color: color)
        continuation.yield(CameraSynchronizedFrame(color: color, depth: depth))
    }
}
