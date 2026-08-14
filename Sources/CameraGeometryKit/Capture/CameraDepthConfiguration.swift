@preconcurrency import AVFoundation
import CoreMedia
import CoreVideo

public struct CameraDepthConfiguration: Sendable, Hashable {
    public let isFilteringEnabled: Bool
    public let preferredPixelFormatTypes: [OSType]

    public init(
        isFilteringEnabled: Bool = false,
        preferredPixelFormatTypes: [OSType] = [
            kCVPixelFormatType_DepthFloat32,
            kCVPixelFormatType_DepthFloat16,
        ]
    ) {
        self.isFilteringEnabled = isFilteringEnabled
        self.preferredPixelFormatTypes = preferredPixelFormatTypes
    }

    func preferredFormat(for device: AVCaptureDevice) -> AVCaptureDevice.Format? {
        let formats = device.activeFormat.supportedDepthDataFormats
        for pixelFormat in preferredPixelFormatTypes {
            let matches = formats.filter {
                CMFormatDescriptionGetMediaSubType($0.formatDescription) == pixelFormat
            }
            if let best = matches.max(by: {
                CMVideoFormatDescriptionGetDimensions($0.formatDescription).width
                    < CMVideoFormatDescriptionGetDimensions($1.formatDescription).width
            }) {
                return best
            }
        }
        return nil
    }
}
