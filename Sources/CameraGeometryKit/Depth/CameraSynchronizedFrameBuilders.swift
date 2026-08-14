import AVFoundation
import CoreMedia
import CoreVideo

extension CameraDepthDelivery {
    func makeColorFrame(
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
}
