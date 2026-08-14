import AVFoundation

extension CameraDeviceRequest {
    func matches(_ other: CameraDeviceRequest) -> Bool {
        let lhsTypes = preferredDeviceTypes.map { $0.rawValue }
        let rhsTypes = other.preferredDeviceTypes.map { $0.rawValue }
        return position == other.position && lhsTypes == rhsTypes
    }
}
