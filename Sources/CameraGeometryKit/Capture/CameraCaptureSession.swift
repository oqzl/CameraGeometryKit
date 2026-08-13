@preconcurrency import AVFoundation
import Foundation
import QuartzCore

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

/// Thin owner of the mutable `AVCaptureSession` graph used by the package.
///
/// Responsibilities are intentionally narrow:
/// - camera authorization;
/// - one video input at a time;
/// - `CameraFrameStream.output`;
/// - `AVCapturePhotoOutput`;
/// - serialized start/stop and camera switching;
/// - capture-angle and canonical non-mirroring policy for frame/photo outputs.
///
/// The exposed `captureSession` exists so apps can attach an
/// `AVCaptureVideoPreviewLayer`. Do not mutate inputs, outputs, or running state
/// through it; use this wrapper so session mutation stays serialized.
public final class CameraCaptureSession: @unchecked Sendable {
    public let captureSession: AVCaptureSession
    public let frameStream: CameraFrameStream
    public let photoOutput: AVCapturePhotoOutput

    private let sessionPreset: AVCaptureSession.Preset
    private let sessionQueue: DispatchQueue
    private let stateLock = NSLock()

    private var videoInput: AVCaptureDeviceInput?
    private var activeDevice: AVCaptureDevice?
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
        queueLabel: String = "net.oqzl.CameraGeometryKit.session"
    ) {
        captureSession = AVCaptureSession()
        photoOutput = AVCapturePhotoOutput()
        self.sessionPreset = sessionPreset
        self.frameStream = frameStream
        sessionQueue = DispatchQueue(label: queueLabel, qos: .userInitiated)
    }

    public var currentState: CameraCaptureSessionState {
        stateLock.withLock { stateStorage }
    }

    /// Requests camera authorization if necessary, configures the minimal
    /// capture graph, and starts the session off the main thread.
    @discardableResult
    public func start(position: CameraPosition = .back) async throws -> CameraCaptureSessionState {
        guard await Self.cameraAccessGranted() else {
            throw CameraCaptureSessionError.cameraPermissionDenied
        }

        return try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [self] in
                do {
                    if !isConfigured {
                        try configureLocked(position: position)
                    } else if currentPositionLocked != position {
                        try setCameraPositionLocked(position)
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

    /// Selects the default wide-angle camera for the requested position.
    /// Reconfiguration is serialized with start/stop and rebuilds the rotation
    /// coordinator for the new physical camera.
    @discardableResult
    public func setCameraPosition(_ position: CameraPosition) async throws -> CameraCaptureSessionState {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [self] in
                do {
                    guard isConfigured else {
                        throw CameraCaptureSessionError.notConfigured
                    }
                    try setCameraPositionLocked(position)
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
                    try setCameraPositionLocked(target)
                    continuation.resume(returning: stateLock.withLock { stateStorage })
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Re-resolves and reapplies the current capture angle immediately before a
    /// photo request. `photoOutput` remains public so the app can own photo
    /// settings and delegate/result policy without duplicating session geometry.
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

    /// Creates the preview-side rotation owner for the currently active device.
    /// Recreate it after `setCameraPosition` / `switchCamera` succeeds.
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

    private func configureLocked(position: CameraPosition) throws {
        let device = try makeDevice(position: position)
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

        guard captureSession.canAddOutput(frameStream.output) else {
            captureSession.removeInput(input)
            captureSession.commitConfiguration()
            throw CameraCaptureSessionError.cannotAddFrameOutput
        }
        captureSession.addOutput(frameStream.output)

        guard captureSession.canAddOutput(photoOutput) else {
            captureSession.removeOutput(frameStream.output)
            captureSession.removeInput(input)
            captureSession.commitConfiguration()
            throw CameraCaptureSessionError.cannotAddPhotoOutput
        }
        captureSession.addOutput(photoOutput)
        captureSession.commitConfiguration()

        videoInput = input
        activeDevice = device
        isConfigured = true
        frameStream.setCameraPosition(device.position)
        rebuildCaptureRotationCoordinatorLocked(for: device)
        updateStateLocked()
    }

    private func setCameraPositionLocked(_ position: CameraPosition) throws {
        guard position != .unspecified else {
            throw CameraCaptureSessionError.cameraUnavailable(position)
        }
        guard currentPositionLocked != position else { return }
        guard let oldInput = videoInput, let oldDevice = activeDevice else {
            throw CameraCaptureSessionError.notConfigured
        }

        let newDevice = try makeDevice(position: position)
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
        captureSession.commitConfiguration()

        videoInput = newInput
        activeDevice = newDevice
        frameStream.setCameraPosition(newDevice.position)
        rebuildCaptureRotationCoordinatorLocked(for: newDevice)
        updateStateLocked()
    }

    private func makeDevice(position: CameraPosition) throws -> AVCaptureDevice {
        let avPosition: AVCaptureDevice.Position
        switch position {
        case .front:
            avPosition = .front
        case .back:
            avPosition = .back
        case .unspecified:
            throw CameraCaptureSessionError.cameraUnavailable(position)
        }

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: avPosition
        ) else {
            throw CameraCaptureSessionError.cameraUnavailable(position)
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
            deviceName: device?.localizedName
        )
        stateLock.withLock {
            activeDeviceForPreview = device
            stateStorage = state
        }
    }
}
