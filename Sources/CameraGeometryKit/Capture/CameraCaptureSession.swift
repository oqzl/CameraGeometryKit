@preconcurrency import AVFoundation
import CoreMedia
import Foundation
import QuartzCore

public enum CameraCaptureSessionError: Error, LocalizedError, Sendable {
    case cameraPermissionDenied
    case cameraUnavailable(CameraPosition)
    case cannotCreateInput(String)
    case cannotAddInput
    case cannotAddFrameOutput
    case cannotAddDepthOutput
    case cannotAddPhotoOutput
    case depthUnavailableForActiveFormat(CameraPosition)
    case cannotConfigureDepth(String)
    case notConfigured

    public var errorDescription: String? {
        switch self {
        case .cameraPermissionDenied: return "Camera access is not authorized."
        case .cameraUnavailable(let position): return "No camera is available for position \(position.rawValue)."
        case .cannotCreateInput(let message): return "Could not create the camera input: \(message)"
        case .cannotAddInput: return "The capture session cannot add the selected camera input."
        case .cannotAddFrameOutput: return "The capture session cannot add the requested frame output."
        case .cannotAddDepthOutput: return "The capture session cannot add the depth output."
        case .cannotAddPhotoOutput: return "The capture session cannot add the photo output."
        case .depthUnavailableForActiveFormat(let position): return "The active video format has no requested depth format for \(position.rawValue) camera."
        case .cannotConfigureDepth(let message): return "Could not configure depth capture: \(message)"
        case .notConfigured: return "The capture session has not been configured."
        }
    }
}

public struct CameraCaptureSessionState: Sendable, Hashable {
    public let isConfigured: Bool
    public let isRunning: Bool
    public let cameraPosition: CameraPosition
    public let deviceUniqueID: String?
    public let deviceName: String?
    public let deviceTypeRawValue: String?
    public let supportsDepthData: Bool
    public let depthCaptureEnabled: Bool

    public init(
        isConfigured: Bool,
        isRunning: Bool,
        cameraPosition: CameraPosition,
        deviceUniqueID: String?,
        deviceName: String?,
        deviceTypeRawValue: String? = nil,
        supportsDepthData: Bool = false,
        depthCaptureEnabled: Bool = false
    ) {
        self.isConfigured = isConfigured
        self.isRunning = isRunning
        self.cameraPosition = cameraPosition
        self.deviceUniqueID = deviceUniqueID
        self.deviceName = deviceName
        self.deviceTypeRawValue = deviceTypeRawValue
        self.supportsDepthData = supportsDepthData
        self.depthCaptureEnabled = depthCaptureEnabled
    }
}

public final class CameraCaptureSession: @unchecked Sendable {
    public let captureSession: AVCaptureSession
    public let frameStream: CameraFrameStream
    public let photoOutput: AVCapturePhotoOutput
    public let synchronizedFrameStream: CameraSynchronizedFrameStream?

    private let sessionPreset: AVCaptureSession.Preset
    private let sessionQueue: DispatchQueue
    private let stateLock = NSLock()
    private let depthConfiguration: CameraDepthCaptureConfiguration?
    private var videoInput: AVCaptureDeviceInput?
    private var activeDevice: AVCaptureDevice?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var captureRotationObservation: NSKeyValueObservation?
    private var isConfigured = false
    private var isRunning = false
    private var activeDeviceForInspection: AVCaptureDevice?
    private var stateStorage = CameraCaptureSessionState(
        isConfigured: false,
        isRunning: false,
        cameraPosition: .unspecified,
        deviceUniqueID: nil,
        deviceName: nil
    )

    public init(
        sessionPreset: AVCaptureSession.Preset = .photo,
        frameStream: CameraFrameStream = CameraFrameStream(),
        depthConfiguration: CameraDepthCaptureConfiguration? = nil,
        queueLabel: String = "net.oqzl.CameraGeometryKit.session"
    ) {
        captureSession = AVCaptureSession()
        photoOutput = AVCapturePhotoOutput()
        self.sessionPreset = sessionPreset
        self.frameStream = frameStream
        self.depthConfiguration = depthConfiguration
        synchronizedFrameStream = depthConfiguration.map { CameraSynchronizedFrameStream(configuration: $0) }
        sessionQueue = DispatchQueue(label: queueLabel, qos: .userInitiated)
    }

    public var currentState: CameraCaptureSessionState { stateLock.withLock { stateStorage } }
    public var activeCaptureDevice: AVCaptureDevice? { stateLock.withLock { activeDeviceForInspection } }

    @discardableResult
    public func start(position: CameraPosition = .back) async throws -> CameraCaptureSessionState {
        try await start(request: .wideAngle(position: position))
    }

    @discardableResult
    public func start(request: CameraDeviceRequest) async throws -> CameraCaptureSessionState {
        guard await Self.cameraAccessGranted() else { throw CameraCaptureSessionError.cameraPermissionDenied }
        return try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [self] in
                do {
                    if !isConfigured { try configureLocked(request: request) }
                    else if activeDeviceDoesNotMatchLocked(request) { try setCameraLocked(request) }
                    if !captureSession.isRunning { captureSession.startRunning() }
                    isRunning = captureSession.isRunning
                    updateStateLocked()
                    continuation.resume(returning: stateLock.withLock { stateStorage })
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    public func stop() async {
        await withCheckedContinuation { continuation in
            sessionQueue.async { [self] in
                if captureSession.isRunning { captureSession.stopRunning() }
                isRunning = false
                updateStateLocked()
                continuation.resume()
            }
        }
    }

    @discardableResult
    public func setCameraPosition(_ position: CameraPosition) async throws -> CameraCaptureSessionState {
        try await setCamera(.wideAngle(position: position))
    }

    @discardableResult
    public func setCamera(_ request: CameraDeviceRequest) async throws -> CameraCaptureSessionState {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [self] in
                do {
                    guard isConfigured else { throw CameraCaptureSessionError.notConfigured }
                    try setCameraLocked(request)
                    continuation.resume(returning: stateLock.withLock { stateStorage })
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    @discardableResult
    public func switchCamera() async throws -> CameraCaptureSessionState {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [self] in
                do {
                    guard isConfigured else { throw CameraCaptureSessionError.notConfigured }
                    let target: CameraPosition = currentPositionLocked == .front ? .back : .front
                    try setCameraLocked(.wideAngle(position: target))
                    continuation.resume(returning: stateLock.withLock { stateStorage })
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    public func preparePhotoCapture() async throws {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [self] in
                guard isConfigured, let rotationCoordinator else {
                    continuation.resume(throwing: CameraCaptureSessionError.notConfigured)
                    return
                }
                applyPhotoConnectionLocked(captureAngle: rotationCoordinator.videoRotationAngleForHorizonLevelCapture)
                continuation.resume()
            }
        }
    }

    @MainActor
    public func makePreviewRotation(previewLayer: CALayer? = nil) -> CameraRotation? {
        guard let device = stateLock.withLock({ activeDeviceForInspection }) else { return nil }
        return CameraRotation(device: device, previewLayer: previewLayer)
    }

    private static func cameraAccessGranted() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted: return false
        @unknown default: return false
        }
    }

    private var currentPositionLocked: CameraPosition {
        activeDevice.map { CameraPosition($0.position) } ?? .unspecified
    }

    private func activeDeviceDoesNotMatchLocked(_ request: CameraDeviceRequest) -> Bool {
        guard let activeDevice, let preferred = CameraDeviceDiscovery.preferredDevice(matching: request) else { return true }
        return activeDevice.uniqueID != preferred.uniqueID
    }

    private func configureLocked(request: CameraDeviceRequest) throws {
        let device = try makeDevice(request: request)
        let input = try makeInput(device: device)
        captureSession.beginConfiguration()
        if captureSession.canSetSessionPreset(sessionPreset) { captureSession.sessionPreset = sessionPreset }
        guard captureSession.canAddInput(input) else {
            captureSession.commitConfiguration()
            throw CameraCaptureSessionError.cannotAddInput
        }
        captureSession.addInput(input)
        do {
            try configureDepthLocked(for: device)
            try addFrameOutputsLocked()
            try addPhotoOutputLocked()
        } catch {
            removeFrameOutputsLocked()
            captureSession.removeInput(input)
            captureSession.commitConfiguration()
            throw error
        }
        captureSession.commitConfiguration()
        videoInput = input
        activeDevice = device
        isConfigured = true
        setStreamCameraPositionLocked(device.position)
        activateSynchronizerLocked()
        rebuildCaptureRotationCoordinatorLocked(for: device)
        updateStateLocked()
    }

    private func setCameraLocked(_ request: CameraDeviceRequest) throws {
        guard let oldInput = videoInput, let oldDevice = activeDevice else { throw CameraCaptureSessionError.notConfigured }
        let newDevice = try makeDevice(request: request)
        guard newDevice.uniqueID != oldDevice.uniqueID else { return }
        let newInput = try makeInput(device: newDevice)
        captureRotationObservation = nil
        rotationCoordinator = nil
        captureSession.beginConfiguration()
        captureSession.removeInput(oldInput)
        guard captureSession.canAddInput(newInput) else {
            restoreLocked(oldInput: oldInput, oldDevice: oldDevice)
            throw CameraCaptureSessionError.cannotAddInput
        }
        captureSession.addInput(newInput)
        do { try configureDepthLocked(for: newDevice) }
        catch {
            captureSession.removeInput(newInput)
            restoreLocked(oldInput: oldInput, oldDevice: oldDevice)
            throw error
        }
        captureSession.commitConfiguration()
        videoInput = newInput
        activeDevice = newDevice
        setStreamCameraPositionLocked(newDevice.position)
        rebuildCaptureRotationCoordinatorLocked(for: newDevice)
        updateStateLocked()
    }

    private func restoreLocked(oldInput: AVCaptureDeviceInput, oldDevice: AVCaptureDevice) {
        if captureSession.canAddInput(oldInput) { captureSession.addInput(oldInput) }
        captureSession.commitConfiguration()
        rebuildCaptureRotationCoordinatorLocked(for: oldDevice)
    }

    private func addFrameOutputsLocked() throws {
        if let stream = synchronizedFrameStream {
            guard captureSession.canAddOutput(stream.videoOutput) else { throw CameraCaptureSessionError.cannotAddFrameOutput }
            captureSession.addOutput(stream.videoOutput)
            guard captureSession.canAddOutput(stream.depthOutput) else {
                captureSession.removeOutput(stream.videoOutput)
                throw CameraCaptureSessionError.cannotAddDepthOutput
            }
            captureSession.addOutput(stream.depthOutput)
        } else {
            guard captureSession.canAddOutput(frameStream.output) else { throw CameraCaptureSessionError.cannotAddFrameOutput }
            captureSession.addOutput(frameStream.output)
        }
    }

    private func removeFrameOutputsLocked() {
        if let stream = synchronizedFrameStream {
            if captureSession.outputs.contains(where: { $0 === stream.depthOutput }) { captureSession.removeOutput(stream.depthOutput) }
            if captureSession.outputs.contains(where: { $0 === stream.videoOutput }) { captureSession.removeOutput(stream.videoOutput) }
        } else if captureSession.outputs.contains(where: { $0 === frameStream.output }) {
            captureSession.removeOutput(frameStream.output)
        }
    }

    private func addPhotoOutputLocked() throws {
        guard captureSession.canAddOutput(photoOutput) else { throw CameraCaptureSessionError.cannotAddPhotoOutput }
        captureSession.addOutput(photoOutput)
    }

    private func configureDepthLocked(for device: AVCaptureDevice) throws {
        guard let configuration = depthConfiguration else { return }
        let formats = device.activeFormat.supportedDepthDataFormats
        var selected: AVCaptureDevice.Format?
        for dataType in configuration.preferredDepthDataTypes {
            let matching = formats.filter { CMFormatDescriptionGetMediaSubType($0.formatDescription) == dataType }
            if let best = matching.max(by: {
                let lhs = CMVideoFormatDescriptionGetDimensions($0.formatDescription)
                let rhs = CMVideoFormatDescriptionGetDimensions($1.formatDescription)
                return Int64(lhs.width) * Int64(lhs.height) < Int64(rhs.width) * Int64(rhs.height)
            }) { selected = best; break }
        }
        guard let selected else {
            throw CameraCaptureSessionError.depthUnavailableForActiveFormat(CameraPosition(device.position))
        }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            device.activeDepthDataFormat = selected
        } catch { throw CameraCaptureSessionError.cannotConfigureDepth(error.localizedDescription) }
    }

    private func activateSynchronizerLocked() {
        guard let stream = synchronizedFrameStream, stream.synchronizer == nil else { return }
        let value = AVCaptureDataOutputSynchronizer(dataOutputs: [stream.videoOutput, stream.depthOutput])
        stream.synchronizer = value
        value.setDelegate(stream, queue: stream.callbackQueue)
    }

    private func setStreamCameraPositionLocked(_ position: AVCaptureDevice.Position) {
        if let synchronizedFrameStream { synchronizedFrameStream.setCameraPosition(position) }
        else { frameStream.setCameraPosition(position) }
    }

    private func makeDevice(request: CameraDeviceRequest) throws -> AVCaptureDevice {
        guard request.position != .unspecified, let device = CameraDeviceDiscovery.preferredDevice(matching: request) else {
            throw CameraCaptureSessionError.cameraUnavailable(request.position)
        }
        return device
    }

    private func makeInput(device: AVCaptureDevice) throws -> AVCaptureDeviceInput {
        do { return try AVCaptureDeviceInput(device: device) }
        catch { throw CameraCaptureSessionError.cannotCreateInput(error.localizedDescription) }
    }

    private func rebuildCaptureRotationCoordinatorLocked(for device: AVCaptureDevice) {
        captureRotationObservation = nil
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
        rotationCoordinator = coordinator
        applyCaptureConnectionsLocked(captureAngle: coordinator.videoRotationAngleForHorizonLevelCapture)
        let deviceUniqueID = device.uniqueID
        captureRotationObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.new]) { [weak self] coordinator, _ in
            let angle = coordinator.videoRotationAngleForHorizonLevelCapture
            self?.sessionQueue.async { [weak self] in
                guard let self, self.activeDevice?.uniqueID == deviceUniqueID else { return }
                self.applyCaptureConnectionsLocked(captureAngle: angle)
            }
        }
    }

    private func applyCaptureConnectionsLocked(captureAngle: CGFloat) {
        let videoConnection = synchronizedFrameStream?.videoOutput.connection(with: .video) ?? frameStream.output.connection(with: .video)
        if let videoConnection {
            if videoConnection.isVideoRotationAngleSupported(captureAngle) { videoConnection.videoRotationAngle = captureAngle }
            CameraConnectionConfiguration.configureCanonicalAnalysisMirroring(on: videoConnection)
        }
        if let depthConnection = synchronizedFrameStream?.depthOutput.connection(with: .depthData) {
            if depthConnection.isVideoRotationAngleSupported(captureAngle) { depthConnection.videoRotationAngle = captureAngle }
            CameraConnectionConfiguration.configureCanonicalAnalysisMirroring(on: depthConnection)
        }
        applyPhotoConnectionLocked(captureAngle: captureAngle)
    }

    private func applyPhotoConnectionLocked(captureAngle: CGFloat) {
        guard let connection = photoOutput.connection(with: .video) else { return }
        if connection.isVideoRotationAngleSupported(captureAngle) { connection.videoRotationAngle = captureAngle }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false
        }
    }

    private func updateStateLocked() {
        let device = activeDevice
        let supportsDepth = device?.formats.contains { !$0.supportedDepthDataFormats.isEmpty } ?? false
        let state = CameraCaptureSessionState(
            isConfigured: isConfigured,
            isRunning: isRunning,
            cameraPosition: device.map { CameraPosition($0.position) } ?? .unspecified,
            deviceUniqueID: device?.uniqueID,
            deviceName: device?.localizedName,
            deviceTypeRawValue: device?.deviceType.rawValue,
            supportsDepthData: supportsDepth,
            depthCaptureEnabled: synchronizedFrameStream != nil
        )
        stateLock.withLock { activeDeviceForInspection = device; stateStorage = state }
    }
}
