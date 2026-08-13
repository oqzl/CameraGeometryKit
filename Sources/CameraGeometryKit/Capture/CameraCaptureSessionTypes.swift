import Foundation

public enum CameraCaptureSessionError: Error, LocalizedError, Sendable {
    case cameraPermissionDenied
    case cameraUnavailable(CameraPosition)
    case cannotCreateInput(String)
    case cannotAddInput
    case cannotAddFrameOutput
    case cannotAddPhotoOutput
    case notConfigured

    public var errorDescription: String? {
        switch self {
        case .cameraPermissionDenied:
            return "Camera access is not authorized."
        case .cameraUnavailable(let position):
            return "No camera is available for position \(position.rawValue)."
        case .cannotCreateInput(let message):
            return "Could not create the camera input: \(message)"
        case .cannotAddInput:
            return "The capture session cannot add the selected camera input."
        case .cannotAddFrameOutput:
            return "The capture session cannot add the video frame output."
        case .cannotAddPhotoOutput:
            return "The capture session cannot add the photo output."
        case .notConfigured:
            return "The capture session has not been configured."
        }
    }
}

public struct CameraCaptureSessionState: Sendable, Hashable {
    public let isConfigured: Bool
    public let isRunning: Bool
    public let cameraPosition: CameraPosition
    public let deviceUniqueID: String?
    public let deviceName: String?

    public init(
        isConfigured: Bool,
        isRunning: Bool,
        cameraPosition: CameraPosition,
        deviceUniqueID: String?,
        deviceName: String?
    ) {
        self.isConfigured = isConfigured
        self.isRunning = isRunning
        self.cameraPosition = cameraPosition
        self.deviceUniqueID = deviceUniqueID
        self.deviceName = deviceName
    }
}
