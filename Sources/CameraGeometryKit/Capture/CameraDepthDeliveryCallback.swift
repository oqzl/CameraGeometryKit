@preconcurrency import AVFoundation

extension CameraDepthDelivery {
    func dataOutputSynchronizer(
        _ synchronizer: AVCaptureDataOutputSynchronizer,
        didOutput collection: AVCaptureSynchronizedDataCollection
    ) {
        deliver(collection)
    }
}
