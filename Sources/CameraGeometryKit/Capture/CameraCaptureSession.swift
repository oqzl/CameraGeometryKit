@preconcurrency import AVFoundation
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
        case .cameraPermissionDenied:
            return "Camera access is not authorized."
        case .cameraUnavailable(let position):
            return "No requested camera is available for position \(position.rawValue)."
        case .cannotCreateInput(let message):
            return "Could not create the camera input: \(message)"
        case .cannotAddInput:
            return "The capture session cannot add the selected camera input."
        case .cannotAddFrameOutput:
            return "The capture session cannot add the video frame output."
        case .cannotAddDepthOutput:
            return "The capture session cannot add the depth output."
        case .cannotAddPhotoOutput:
            return "The capture session cannot add the photo output."
        case .depthUnavailableForActiveFormat(let position):
            return "The active video format does not provide a requested depth format for \(position.rawValue) camera."
        case .cannotConfigureDepth(let message):
            return "Could not configure depth capture: \(message)"
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

/// Thin owner of the mutable `AVCaptureSession` graph used by the package.
///
/// The wrapper owns one capability-selected video input, bounded color frames,
/// optional synchronized depth, photo output, serialized graph mutation,
/// capture rotation, and canonical non-mirroring. Product recording, effects,
/// camera chrome, and workflow state remain outside the package.
public final class CameraCaptureSession: @unchecked Sendable {
    public let captureSession: AVCaptureSession
    public let frameStream: CameraFrameStream
    public let photoOutput: AVCapturePhotoOutput

    public var depthOutput: AVCaptureDepthDataOutput? {
        depthOutputStorage
    }

    private let sessionPreset: AVCaptureSession.Preset
    private let sessionQueue: DispatchQueue
    private let stateLock = NSLock()
    private let depthConfiguration: CameraDepthConfiguration?
    private let depthOutputStorage: AVCaptureDepthDataOutput?

    private var depthDelivery: CameraDepthDelivery?
    private var videoInput: AVCaptureDeviceInput?
    private var activeDevice: AVCaptureDevice?
    private var activeDeviceRequest: CameraDeviceRequest?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var captureRotationObservation: NSKeyValueObservation?
    private var isConfigured = false
    private var isRunning = false

    private var activeDeviceForPreview: AVCaptureDevice?
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
        depthConfiguration: CameraDepthConfiguration? = nil,
        queueLabel: String = "net.oqzl.CameraGeometryKit.session"
    ) {
        captureSession = AVCaptureSession()
        photoOutput = AVCapturePhotoOutput()
        self.sessionPreset = sessionPreset
        self.frameStream = frameStream
        self.depthConfiguration = depthConfiguration

        if let depthConfiguration {
            let output = AVCaptureDepthDataOutput()
            output.alwaysDiscardsLateDepthData = true
            output.isFilteringEnabled = depthConfiguration.isFilteringEnabled
            depthOutputStorage = output
        } else {
            depthOutputStorage = nil
        }

        sessionQueue = DispatchQueue(label: queueLabel, qos: .userInitiated)
    }

    public var currentState: CameraCaptureSessionState {
        stateLock.withLock { stateStorage }
    }

    @discardableResult
    public func start(position: CameraPosition = .back) async throws -> CameraCaptureSessionState {
        try await start(deviceRequest: .wideAngle(position: position))
    }

    @discardableResult
    public func start(deviceRequest: CameraDeviceRequest) async throws -> CameraCaptureSessionState {
        guard await Self.cameraAccessGranted() else {
            throw CameraCaptureSessionError.cameraPermissionDenied
        }

        return try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [self] in
                do {
                    if !isConfigured {
                        try configureLocked(deviceRequest: deviceRequest)
                    } else if activeDeviceRequest?.matches(deviceRequest) != true {
                        try setDeviceLocked(deviceRequest)
                    }

                    if !captureSession.isRunning {
                        captureSession.startRunning()
                    }
                    isRunning = captureSession.isRunning
                    updateStateLocked()
                    continuation.resume(returning: stateLock.withLock { stateStorage })
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func stop() async {
        await withCheckedContinuation { continuation in
            sessionQueue.async { [self] in
                if captureSession.isRunning {
                    captureSession.stopRunning()
                }
                isRunning = false
                updateStateLocked()
                continuation.resume()
            }
        }
    }

    @discardableResult
    public func setCameraPosition(_ position: CameraPosition) async throws -> CameraCaptureSessionState {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [self] in
                do {
                    guard isConfigured else {
                        throw CameraCaptureSessionError.notConfigured
                    }
                    let request = (activeDeviceRequest ?? .wideAngle(position: currentPositionLocked))
                        .withPosition(position)
                    try setDeviceLocked(request)
                    continuation.resume(returning: stateLock.withLock { stateStorage })
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    @discardableResult
    public func setDevice(_ request: CameraDeviceRequest) async throws -> CameraCaptureSessionState {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [self] in
                do {
                    guard isConfigured else {
                        throw CameraCaptureSessionError.notConfigured
                    }
                    try setDeviceLocked(request)
                    continuation.resume(returning: stateLock.withLock { stateStorage })
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    @discardableResult
    public func switchCamera() async throws -> CameraCaptureSessionState {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [self] in
                do {
                    guard isConfigured else {
                        throw CameraCaptureSessionError.notConfigured
                    }
                    let target: CameraPosition = currentPositionLocked == .front ? .back : .front
                    let request = (activeDeviceRequest ?? .wideAngle(position: currentPositionLocked))
                        .withPosition(target)
                    try setDeviceLocked(request)
                    continuation.resume(returning: stateLock.withLock { stateStorage })
                } catch {
                    continuation.resume(throwing: error)
                }
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
                applyPhotoConnectionLocked(
                    captureAngle: rotationCoordinator.videoRotationAngleForHorizonLevelCapture
                )
                continuation.resume()
            }
        }
    }

    @MainActor
    public func makePreviewRotation(previewLayer: CALayer? = nil) -> CameraRotation? {
        guard let device = stateLock.withLock({ activeDeviceForPreview }) else { return nil }
        return CameraRotation(device: device, previewLayer: previewLayer)
    }

    private static func cameraAccessGranted() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private var currentPositionLocked: CameraPosition {
        activeDevice.map { CameraPosition($0.position) } ?? .unspecified
    }

    private func configureLocked(deviceRequest: CameraDeviceRequest) throws {
        let device = try makeDevice(request: deviceRequest)
        let input = try makeInput(device: device)

        captureSession.beginConfiguration()
        if captureSession.canSetSessionPreset(sessionPreset) {
            captureSession.sessionPreset = sessionPreset
        }

        guard captureSession.canAddInput(input) else {
            captureSession.commitConfiguration()
            throw CameraCaptureSessionError.cannotAddInput
        }
        captureSession.addInput(input)

        do {
            try configureDepthDeviceIfNeeded(device)
        } catch {
            captureSession.removeInput(input)
            captureSession.commitConfiguration()
            throw error
        }

        guard captureSession.canAddOutput(frameStream.output) else {
            captureSession.removeInput(input)
            captureSession.commitConfiguration()
            throw CameraCaptureSessionError.cannotAddFrameOutput
        }
        captureSession.addOutput(frameStream.output)

        if let depthOutput {
            guard captureSession.canAddOutput(depthOutput) else {
                captureSession.removeOutput(frameStream.output)
                captureSession.removeInput(input)
                captureSession.commitConfiguration()
                throw CameraCaptureSessionError.cannotAddDepthOutput
            }
            captureSession.addOutput(depthOutput)
            depthOutput.connection(with: .depthData)?.isEnabled = true
        }

        guard captureSession.canAddOutput(photoOutput) else {
            if let depthOutput {
                captureSession.removeOutput(depthOutput)
            }
            captureSession.removeOutput(frameStream.output)
            captureSession.removeInput(input)
            captureSession.commitConfiguration()
            throw CameraCaptureSessionError.cannotAddPhotoOutput
        }
        captureSession.addOutput(photoOutput)
        captureSession.commitConfiguration()

        if let depthOutput {
            let delivery = CameraDepthDelivery(
                frameStream: frameStream,
                depthOutput: depthOutput
            )
            depthDelivery = delivery
            delivery.start()
        }

        videoInput = input
        activeDevice = device
        activeDeviceRequest = deviceRequest
        isConfigured = true
        frameStream.setCameraPosition(device.position)
        rebuildCaptureRotationCoordinatorLocked(for: device)
        updateStateLocked()
    }

    private func setDeviceLocked(_ request: CameraDeviceRequest) throws {
        guard request.position != .unspecified else {
            throw CameraCaptureSessionError.cameraUnavailable(request.position)
        }
        guard let oldInput = videoInput, let oldDevice = activeDevice else {
            throw CameraCaptureSessionError.notConfigured
        }

        let newDevice = try makeDevice(request: request)
        if newDevice.uniqueID == oldDevice.uniqueID {
            activeDeviceRequest = request
            updateStateLocked()
            return
        }
        let newInput = try makeInput(device: newDevice)

        captureRotationObservation = nil
        rotationCoordinator = nil

        captureSession.beginConfiguration()
        captureSession.removeInput(oldInput)

        guard captureSession.canAddInput(newInput) else {
            if captureSession.canAddInput(oldInput) {
                captureSession.addInput(oldInput)
            }
            captureSession.commitConfiguration()
            rebuildCaptureRotationCoordinatorLocked(for: oldDevice)
            throw CameraCaptureSessionError.cannotAddInput
        }
        captureSession.addInput(newInput)

        do {
            try configureDepthDeviceIfNeeded(newDevice)
        } catch {
            captureSession.removeInput(newInput)
            if captureSession.canAddInput(oldInput) {
                captureSession.addInput(oldInput)
            }
            captureSession.commitConfiguration()
            rebuildCaptureRotationCoordinatorLocked(for: oldDevice)
            throw error
        }

        captureSession.commitConfiguration()

        videoInput = newInput
        activeDevice = newDevice
        activeDeviceRequest = request
        frameStream.setCameraPosition(newDevice.position)
        rebuildCaptureRotationCoordinatorLocked(for: newDevice)
        updateStateLocked()
    }

    private func makeDevice(request: CameraDeviceRequest) throws -> AVCaptureDevice {
        guard let device = CameraDeviceDiscovery.preferredDevice(for: request) else {
            throw CameraCaptureSessionError.cameraUnavailable(request.position)
        }
        return device
    }

    private func makeInput(device: AVCaptureDevice) throws -> AVCaptureDeviceInput {
        do {
            return try AVCaptureDeviceInput(device: device)
        } catch {
            throw CameraCaptureSessionError.cannotCreateInput(error.localizedDescription)
        }
    }

    private func configureDepthDeviceIfNeeded(_ device: AVCaptureDevice) throws {
        guard let depthConfiguration else { return }
        guard let depthFormat = depthConfiguration.preferredFormat(for: device) else {
            throw CameraCaptureSessionError.depthUnavailableForActiveFormat(
                CameraPosition(device.position)
            )
        }

        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            device.activeDepthDataFormat = depthFormat
        } catch {
            throw CameraCaptureSessionError.cannotConfigureDepth(error.localizedDescription)
        }
    }

    private func rebuildCaptureRotationCoordinatorLocked(for device: AVCaptureDevice) {
        captureRotationObservation = nil
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
        rotationCoordinator = coordinator

        applyCaptureConnectionsLocked(
            captureAngle: coordinator.videoRotationAngleForHorizonLevelCapture
        )

        let deviceUniqueID = device.uniqueID
        captureRotationObservation = coordinator.observe(
            \.videoRotationAngleForHorizonLevelCapture,
            options: [.new]
        ) { [weak self] coordinator, _ in
            let angle = coordinator.videoRotationAngleForHorizonLevelCapture
            self?.sessionQueue.async { [weak self] in
                guard let self, self.activeDevice?.uniqueID == deviceUniqueID else { return }
                self.applyCaptureConnectionsLocked(captureAngle: angle)
            }
        }
    }

    private func applyCaptureConnectionsLocked(captureAngle: CGFloat) {
        if let connection = frameStream.output.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(captureAngle) {
                connection.videoRotationAngle = captureAngle
            }
            CameraConnectionConfiguration.configureCanonicalAnalysisMirroring(on: connection)
        }
        if let connection = depthOutput?.connection(with: .depthData) {
            if connection.isVideoRotationAngleSupported(captureAngle) {
                connection.videoRotationAngle = captureAngle
            }
            CameraConnectionConfiguration.configureCanonicalAnalysisMirroring(on: connection)
        }
        applyPhotoConnectionLocked(captureAngle: captureAngle)
    }

    private func applyPhotoConnectionLocked(captureAngle: CGFloat) {
        guard let connection = photoOutput.connection(with: .video) else { return }
        if connection.isVideoRotationAngleSupported(captureAngle) {
            connection.videoRotationAngle = captureAngle
        }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false
        }
    }

    private func updateStateLocked() {
        let device = activeDevice
        let state = CameraCaptureSessionState(
            isConfigured: isConfigured,
            isRunning: isRunning,
            cameraPosition: device.map { CameraPosition($0.position) } ?? .unspecified,
            deviceUniqueID: device?.uniqueID,
            deviceName: device?.localizedName,
            deviceTypeRawValue: device?.deviceType.rawValue,
            supportsDepthData: device?.formats.contains { !$0.supportedDepthDataFormats.isEmpty } ?? false,
            depthCaptureEnabled: depthConfiguration != nil
        )
        stateLock.withLock {
            activeDeviceForPreview = device
            stateStorage = state
        }
    }
}
