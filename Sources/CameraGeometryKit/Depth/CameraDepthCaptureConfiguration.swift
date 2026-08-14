import CoreVideo

public struct CameraDepthCaptureConfiguration: Sendable, Hashable {
    public let isFilteringEnabled: Bool
    public let preferredDepthDataTypes: [OSType]

    public init(
        isFilteringEnabled: Bool = false,
        preferredDepthDataTypes: [OSType] = [kCVPixelFormatType_DepthFloat32, kCVPixelFormatType_DepthFloat16]
    ) {
        self.isFilteringEnabled = isFilteringEnabled
        self.preferredDepthDataTypes = preferredDepthDataTypes
    }
}
