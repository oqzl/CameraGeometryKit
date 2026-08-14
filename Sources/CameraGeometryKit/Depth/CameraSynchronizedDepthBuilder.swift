import AVFoundation
import CoreVideo

extension CameraDepthDelivery {
    func makeDepthFrame(
        _ sample: AVCaptureSynchronizedDepthData?,
        color: CameraFrame
    ) -> CameraDepthFrame? {
        guard let sample, !sample.depthDataWasDropped else { return nil }
        let data = sample.depthData
        let map = data.depthDataMap
        let connection = depthOutput.connection(with: .depthData)

        return CameraDepthFrame(
            depthData: data,
            timestamp: sample.timestamp,
            geometry: CameraDepthFrameGeometry(
                pixelWidth: CVPixelBufferGetWidth(map),
                pixelHeight: CVPixelBufferGetHeight(map),
                cameraPosition: color.geometry.cameraPosition,
                appliedVideoRotationAngle: connection?.videoRotationAngle
                    ?? color.geometry.appliedVideoRotationAngle,
                isMirrored: connection?.isVideoMirrored ?? color.geometry.isMirrored,
                depthDataType: data.depthDataType,
                isFiltered: data.isDepthDataFiltered
            )
        )
    }
}
