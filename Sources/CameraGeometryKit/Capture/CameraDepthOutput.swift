@preconcurrency import AVFoundation

public final class CameraDepthOutput: @unchecked Sendable {
    public let output: AVCaptureDepthDataOutput

    public init(configuration: CameraDepthConfiguration = CameraDepthConfiguration()) {
        output = AVCaptureDepthDataOutput()
        output.alwaysDiscardsLateDepthData = true
        output.isFilteringEnabled = configuration.isFilteringEnabled
    }
}
