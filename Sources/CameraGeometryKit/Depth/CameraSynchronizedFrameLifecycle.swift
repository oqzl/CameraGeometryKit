import AVFoundation

extension CameraDepthDelivery {
    func setCameraPosition(_ position: AVCaptureDevice.Position) {
        lock.withLock { cameraPosition = CameraPosition(position) }
    }
}
