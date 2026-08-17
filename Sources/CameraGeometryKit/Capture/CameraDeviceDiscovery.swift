@preconcurrency import AVFoundation
import Foundation

/// A capability-based request for a physical or virtual camera device.
///
/// With `uniqueID == nil`, device types are tried in the order supplied.
/// With `uniqueID != nil`, the request targets exactly that device and the
/// position/type fields are used to validate that a stale or mismatched device
/// is not selected accidentally.
///
/// Set `requiresDepthData` when the selected device must expose at least one
/// video format with compatible depth data. The active video/depth format pair
/// is still validated later by `CameraCaptureSession`.
///
/// Selection is based entirely on what AVFoundation reports at runtime; callers
/// should not branch on iPhone model identifiers.
public struct CameraDeviceRequest: @unchecked Sendable {
    public let uniqueID: String?
    public let position: CameraPosition
    public let preferredDeviceTypes: [AVCaptureDevice.DeviceType]
    public let requiresDepthData: Bool

    public init(
        position: CameraPosition,
        preferredDeviceTypes: [AVCaptureDevice.DeviceType],
        uniqueID: String? = nil,
        requiresDepthData: Bool = false
    ) {
        self.uniqueID = uniqueID
        self.position = position
        self.preferredDeviceTypes = preferredDeviceTypes
        self.requiresDepthData = requiresDepthData
    }

    public init(device: CameraDeviceInfo, requiresDepthData: Bool = false) {
        self.init(
            position: device.position,
            preferredDeviceTypes: [device.deviceType],
            uniqueID: device.uniqueID,
            requiresDepthData: requiresDepthData
        )
    }

    public static func wideAngle(position: CameraPosition) -> CameraDeviceRequest {
        CameraDeviceRequest(
            position: position,
            preferredDeviceTypes: [.builtInWideAngleCamera]
        )
    }

    func requiringDepthData() -> CameraDeviceRequest {
        guard !requiresDepthData else { return self }
        return CameraDeviceRequest(
            position: position,
            preferredDeviceTypes: preferredDeviceTypes,
            uniqueID: uniqueID,
            requiresDepthData: true
        )
    }
}

public struct CameraDeviceInfo: @unchecked Sendable, Hashable, Identifiable {
    public let uniqueID: String
    public let localizedName: String
    public let deviceType: AVCaptureDevice.DeviceType
    public let position: CameraPosition
    public let supportsDepthData: Bool
    public let minZoomFactor: CGFloat
    public let maxZoomFactor: CGFloat

    public var id: String { uniqueID }
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
    /// Current nondeprecated camera device types relevant to iOS camera apps.
    public static let videoDeviceTypes: [AVCaptureDevice.DeviceType] = [
        .builtInUltraWideCamera,
        .builtInWideAngleCamera,
        .builtInTelephotoCamera,
        .builtInDualCamera,
        .builtInDualWideCamera,
        .builtInTripleCamera,
        .builtInTrueDepthCamera,
        .builtInLiDARDepthCamera,
        .continuityCamera,
        .external,
    ]

    /// Returns matching devices in the same priority order as
    /// `preferredDeviceTypes`. An exact request returns either one matching
    /// device or an empty array.
    public static func devices(matching request: CameraDeviceRequest) -> [AVCaptureDevice] {
        if let uniqueID = request.uniqueID {
            guard let device = AVCaptureDevice(uniqueID: uniqueID),
                  request.position == CameraPosition(device.position),
                  request.preferredDeviceTypes.contains(device.deviceType),
                  !request.requiresDepthData || supportsDepthData(device)
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

        let ordered = request.preferredDeviceTypes.flatMap { type in
            discovered.filter { $0.deviceType == type }
        }
        guard request.requiresDepthData else { return ordered }
        return ordered.filter { supportsDepthData($0) }
    }

    public static func preferredDevice(matching request: CameraDeviceRequest) -> AVCaptureDevice? {
        devices(matching: request).first
    }

    /// Returns stable, app-facing metadata for all devices matching the request.
    public static func deviceInfos(matching request: CameraDeviceRequest) -> [CameraDeviceInfo] {
        devices(matching: request).map(info(for:))
    }

    /// Returns every currently discoverable video device for one position.
    public static func availableDeviceInfos(position: CameraPosition) -> [CameraDeviceInfo] {
        deviceInfos(
            matching: CameraDeviceRequest(
                position: position,
                preferredDeviceTypes: videoDeviceTypes
            )
        )
    }

    /// Returns front and back devices suitable for presenting a device picker.
    public static func availableDeviceInfos() -> [CameraDeviceInfo] {
        availableDeviceInfos(position: .back) + availableDeviceInfos(position: .front)
    }

    public static func info(for device: AVCaptureDevice) -> CameraDeviceInfo {
        CameraDeviceInfo(
            uniqueID: device.uniqueID,
            localizedName: device.localizedName,
            deviceType: device.deviceType,
            position: CameraPosition(device.position),
            supportsDepthData: supportsDepthData(device),
            minZoomFactor: device.minAvailableVideoZoomFactor,
            maxZoomFactor: device.maxAvailableVideoZoomFactor
        )
    }

    private static func supportsDepthData(_ device: AVCaptureDevice) -> Bool {
        device.formats.contains { !$0.supportedDepthDataFormats.isEmpty }
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
