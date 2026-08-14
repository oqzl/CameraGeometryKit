import AVFoundation

extension CameraSynchronizedFrameStream {
    func setCameraPosition(_ position: AVCaptureDevice.Position) {
        lock.withLock { cameraPosition = CameraPosition(position) }
    }
}
