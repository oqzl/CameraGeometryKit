@preconcurrency import AVFoundation
import Foundation

/// A capability-based request for a physical capture device.
///
/// Device types are ordered by preference. Resolution is delegated to
/// `AVCaptureDevice.DiscoverySession`; product code must not branch on iPhone
/// model identifiers to choose a camera.
public struct CameraDeviceRequest: @unchecked Sendable {
    public let position: CameraPosition
    public let preferredDeviceTypes: [AVCaptureDevice.DeviceType]

    public init(
        position: CameraPosition,
        preferredDeviceTypes: [AVCaptureDevice.DeviceType]
    ) {
        precondition(position != .unspecified, "CameraDeviceRequest requires front or back position.")
        precondition(!preferredDeviceTypes.isEmpty, "CameraDeviceRequest requires at least one device type.")
        self.position = position
        self.preferredDeviceTypes = preferredDeviceTypes
    }

    public static func wideAngle(position: CameraPosition) -> Self {
        Self(
            position: position,
            preferredDeviceTypes: [.builtInWideAngleCamera]
        )
    }

    public func withPosition(_ position: CameraPosition) -> Self {
        Self(position: position, preferredDeviceTypes: preferredDeviceTypes)
    }
}

/// Stable, Sendable information about a discovered capture device.
public struct CameraDeviceDescriptor: Sendable, Hashable {
    public let uniqueID: String
    public let localizedName: String
    public let position: CameraPosition
    public let deviceTypeRawValue: String
    public let supportsDepthData: Bool
    public let minZoomFactor: CGFloat
    public let maxZoomFactor: CGFloat

    init(device: AVCaptureDevice) {
        uniqueID = device.uniqueID
        localizedName = device.localizedName
        position = CameraPosition(device.position)
        deviceTypeRawValue = device.deviceType.rawValue
        supportsDepthData = device.formats.contains { !$0.supportedDepthDataFormats.isEmpty }
        minZoomFactor = device.minAvailableVideoZoomFactor
        maxZoomFactor = device.maxAvailableVideoZoomFactor
    }
}

/// Discovers cameras from AVFoundation-reported capabilities rather than
/// device-model assumptions.
public enum CameraDeviceDiscovery {
    public static func availableDevices(
        for request: CameraDeviceRequest
    ) -> [CameraDeviceDescriptor] {
        discoverySession(for: request).devices.map(CameraDeviceDescriptor.init)
    }

    public static func preferredDeviceDescriptor(
        for request: CameraDeviceRequest
    ) -> CameraDeviceDescriptor? {
        preferredDevice(for: request).map(CameraDeviceDescriptor.init)
    }

    static func preferredDevice(for request: CameraDeviceRequest) -> AVCaptureDevice? {
        discoverySession(for: request).devices.first
    }

    private static func discoverySession(
        for request: CameraDeviceRequest
    ) -> AVCaptureDevice.DiscoverySession {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: request.preferredDeviceTypes,
            mediaType: .video,
            position: request.position.avCapturePosition
        )
    }
}

extension CameraPosition {
    var avCapturePosition: AVCaptureDevice.Position {
        switch self {
        case .front: .front
        case .back: .back
        case .unspecified: .unspecified
        }
    }
}
