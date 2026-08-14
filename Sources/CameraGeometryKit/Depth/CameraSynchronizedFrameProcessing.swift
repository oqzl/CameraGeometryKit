import AVFoundation

extension CameraDepthDelivery {
    public func dataOutputSynchronizer(
        _ synchronizer: AVCaptureDataOutputSynchronizer,
        didOutput collection: AVCaptureSynchronizedDataCollection
    ) {}
}
