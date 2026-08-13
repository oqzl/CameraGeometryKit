@preconcurrency import AVFoundation
import Foundation

public extension CameraCaptureSession {
    @discardableResult
    func start(position: CameraPosition = .back) async throws -> CameraCaptureSessionState {
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
                    if !captureSession.isRunning { captureSession.startRunning() }
                    isRunning = captureSession.isRunning
                    updateStateLocked()
                    continuation.resume(returning: stateLock.withLock { stateStorage })
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func stop() async {
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
    func setCameraPosition(_ position: CameraPosition) async throws -> CameraCaptureSessionState {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [self] in
                do {
                    guard isConfigured else { throw CameraCaptureSessionError.notConfigured }
                    try setCameraPositionLocked(position)
                    continuation.resume(returning: stateLock.withLock { stateStorage })
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    @discardableResult
    func switchCamera() async throws -> CameraCaptureSessionState {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [self] in
                do {
                    guard isConfigured else { throw CameraCaptureSessionError.notConfigured }
                    let target: CameraPosition = currentPositionLocked == .front ? .back : .front
                    try setCameraPositionLocked(target)
                    continuation.resume(returning: stateLock.withLock { stateStorage })
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func preparePhotoCapture() async throws {
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
}

extension CameraCaptureSession {
    static func cameraAccessGranted() async -> Bool {
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
}
