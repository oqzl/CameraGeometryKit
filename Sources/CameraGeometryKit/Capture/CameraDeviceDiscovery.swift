@preconcurrency import AVFoundation
import Foundation

/// A capability-based request for a physical or virtual camera device.
///
/// Device types are tried in the order supplied. Selection is based entirely on
/// what AVFoundation reports at runtime; callers should not branch on iPhone
/// model identifiers.
public struct CameraDeviceRequest: @unchecked Sendable {
    public let position: CameraPosition
    public let preferredDeviceTypes: [AVCaptureDevice.DeviceType]

    public init(
        position: CameraPosition,
        preferredDeviceTypes: [AVCaptureDevice.DeviceType]
    ) {
        self.position = position
        self.preferredDeviceTypes = preferredDeviceTypes
    }

    public static func wideAngle(position: CameraPosition) -> CameraDeviceRequest {
        CameraDeviceRequest(
            position: position,
            preferredDeviceTypes: [.builtInWideAngleCamera]
        )
    }
}

public struct CameraDeviceInfo: Sendable, Hashable {
    public let uniqueID: String
    public let localizedName: String
    public let deviceTypeRawValue: String
    public let position: CameraPosition
    public let supportsDepthData: Bool
    public let minZoomFactor: CGFloat
    public let maxZoomFactor: CGFloat

    public init(
        uniqueID: String,
        localizedName: String,
        deviceTypeRawValue: String,
        position: CameraPosition,
        supportsDepthData: Bool,
        minZoomFactor: CGFloat,
        maxZoomFactor: CGFloat
    ) {
        self.uniqueID = uniqueID
        self.localizedName = localizedName
        self.deviceTypeRawValue = deviceTypeRawValue
        self.position = position
        self.supportsDepthData = supportsDepthData
        self.minZoomFactor = minZoomFactor
        self.maxZoomFactor = maxZoomFactor
    }
}

public enum CameraDeviceDiscovery {
    /// Returns matching devices in the same priority order as
    /// `preferredDeviceTypes`.
    public static func devices(matching request: CameraDeviceRequest) -> [AVCaptureDevice] {
        guard let position = request.position.avFoundationPosition,
              !request.preferredDeviceTypes.isEmpty
        else {
            return []
        }

        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: request.preferredDeviceTypes,
            mediaType: .video,
            position: position
        )
        let discovered = discovery.devices

        return request.preferredDeviceTypes.flatMap { type in
            discovered.filter { $0.deviceType == type }
        }
    }

    public static func preferredDevice(matching request: CameraDeviceRequest) -> AVCaptureDevice? {
        devices(matching: request).first
    }

    public static func info(for device: AVCaptureDevice) -> CameraDeviceInfo {
        CameraDeviceInfo(
            uniqueID: device.uniqueID,
            localizedName: device.localizedName,
            deviceTypeRawValue: device.deviceType.rawValue,
            position: CameraPosition(device.position),
            supportsDepthData: device.formats.contains { !$0.supportedDepthDataFormats.isEmpty },
            minZoomFactor: device.minAvailableVideoZoomFactor,
            maxZoomFactor: device.maxAvailableVideoZoomFactor
        )
    }
}

extension CameraPosition {
    var avFoundationPosition: AVCaptureDevice.Position? {
        switch self {
        case .front:
            .front
        case .back:
            .back
        case .unspecified:
            nil
        }
    }
}
