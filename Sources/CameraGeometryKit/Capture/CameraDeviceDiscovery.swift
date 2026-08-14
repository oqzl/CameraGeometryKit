@preconcurrency import AVFoundation
import Foundation

/// A capability-based request for a physical or virtual camera device.
///
/// With `uniqueID == nil`, device types are tried in the order supplied.
/// With `uniqueID != nil`, the request targets exactly that device and the
/// position/type fields are used to validate that a stale or mismatched device
/// is not selected accidentally.
///
/// Selection is based entirely on what AVFoundation reports at runtime; callers
/// should not branch on iPhone model identifiers.
public struct CameraDeviceRequest: @unchecked Sendable {
    public let uniqueID: String?
    public let position: CameraPosition
    public let preferredDeviceTypes: [AVCaptureDevice.DeviceType]

    public init(
        position: CameraPosition,
        preferredDeviceTypes: [AVCaptureDevice.DeviceType],
        uniqueID: String? = nil
    ) {
        self.uniqueID = uniqueID
        self.position = position
        self.preferredDeviceTypes = preferredDeviceTypes
    }

    public init(device: CameraDeviceInfo) {
        self.init(
            position: device.position,
            preferredDeviceTypes: [device.deviceType],
            uniqueID: device.uniqueID
        )
    }

    public static func wideAngle(position: CameraPosition) -> CameraDeviceRequest {
        CameraDeviceRequest(
            position: position,
            preferredDeviceTypes: [.builtInWideAngleCamera]
        )
    }
}

public struct CameraDeviceInfo: @unchecked Sendable, Hashable {
    public let uniqueID: String
    public let localizedName: String
    public let deviceType: AVCaptureDevice.DeviceType
    public let position: CameraPosition
    public let supportsDepthData: Bool
    public let minZoomFactor: CGFloat
    public let maxZoomFactor: CGFloat

    public var deviceTypeRawValue: String { deviceType.rawValue }

    public init(
        uniqueID: String,
        localizedName: String,
        deviceType: AVCaptureDevice.DeviceType,
        position: CameraPosition,
        supportsDepthData: Bool,
        minZoomFactor: CGFloat,
        maxZoomFactor: CGFloat
    ) {
        self.uniqueID = uniqueID
        self.localizedName = localizedName
        self.deviceType = deviceType
        self.position = position
        self.supportsDepthData = supportsDepthData
        self.minZoomFactor = minZoomFactor
        self.maxZoomFactor = maxZoomFactor
    }
}

public enum CameraDeviceDiscovery {
    /// Returns matching devices in the same priority order as
    /// `preferredDeviceTypes`. An exact request returns either one matching
    /// device or an empty array.
    public static func devices(matching request: CameraDeviceRequest) -> [AVCaptureDevice] {
        if let uniqueID = request.uniqueID {
            guard let device = AVCaptureDevice(uniqueID: uniqueID),
                  request.position == CameraPosition(device.position),
                  request.preferredDeviceTypes.contains(device.deviceType)
            else {
                return []
            }
            return [device]
        }

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

    /// Returns stable, app-facing metadata for all devices matching the request.
    public static func deviceInfos(matching request: CameraDeviceRequest) -> [CameraDeviceInfo] {
        devices(matching: request).map(info(for:))
    }

    public static func info(for device: AVCaptureDevice) -> CameraDeviceInfo {
        CameraDeviceInfo(
            uniqueID: device.uniqueID,
            localizedName: device.localizedName,
            deviceType: device.deviceType,
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
