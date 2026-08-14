import AVFoundation
import CameraGeometryKit
import CoreMedia
import Foundation
import SwiftUI

struct LibrarySessionDiagnostics: Equatable {
    let deviceType: String?
    let activeFormatWidth: Int
    let activeFormatHeight: Int
    let analysisConnectionRotationAngle: CGFloat?
    let analysisMirrored: Bool?
    let photoConnectionRotationAngle: CGFloat?
    let photoMirrored: Bool?
}

struct LibraryDeliveredFrameDiagnostics: Equatable, Sendable {
    let frameID: UInt64
    let cameraPosition: CameraPosition
    let pixelWidth: Int
    let pixelHeight: Int
    let appliedVideoRotationAngle: CGFloat
    let isMirrored: Bool
}

private struct FrameHUDSnapshot: Sendable {
    let diagnostics: LibraryDeliveredFrameDiagnostics
    let statistics: CameraFrameStreamStatistics
}

@MainActor
final class CameraSampleModel: ObservableObject {
    @Published private(set) var state = CameraCaptureSessionState(
        isConfigured: false,
        isRunning: false,
        cameraPosition: .unspecified,
        deviceUniqueID: nil,
        deviceName: nil
    )
    @Published private(set) var frameSummary = "フレーム待機中"
    @Published private(set) var statistics = CameraFrameStreamStatistics(
        deliveredFrames: 0,
        droppedByAVFoundation: 0,
        replacedInLatestBuffer: 0
    )
    @Published private(set) var librarySessionDiagnostics: LibrarySessionDiagnostics?
    @Published private(set) var deliveredFrameDiagnostics: LibraryDeliveredFrameDiagnostics?
    @Published private(set) var errorMessage: String?
    @Published var requestedPosition: CameraPosition = .back

    let camera: CameraCaptureSession

    init(camera: CameraCaptureSession = CameraCaptureSession(sessionPreset: .high)) {
        self.camera = camera
    }

    var isRunning: Bool { state.isRunning }

    var positionTitle: String {
        switch state.cameraPosition {
        case .front: "前面カメラ"
        case .back: "背面カメラ"
        case .unspecified: "未選択"
        }
    }

    func runSession() async {
        do {
            state = try await camera.start(position: requestedPosition)
            librarySessionDiagnostics = makeLibrarySessionDiagnostics()
            errorMessage = nil

            let camera = camera
            let consumer = Task.detached(priority: .userInitiated) { [weak self, camera] in
                await Self.consumeFrames(camera: camera) { snapshot in
                    guard let self else { return }
                    self.apply(snapshot)
                }
            }

            await withTaskCancellationHandler {
                await consumer.value
            } onCancel: {
                consumer.cancel()
            }
        } catch is CancellationError {
            // Expected when the sample leaves the screen.
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }

        await camera.stop()
        if !Task.isCancelled {
            state = camera.currentState
            librarySessionDiagnostics = makeLibrarySessionDiagnostics()
        }
    }

    func switchCamera(to position: CameraPosition) async {
        guard isRunning, state.cameraPosition != position else { return }

        do {
            let nextState = try await camera.setCameraPosition(position)
            guard !Task.isCancelled else { return }
            state = nextState
            librarySessionDiagnostics = makeLibrarySessionDiagnostics()
            errorMessage = nil
        } catch is CancellationError {
            // A newer position request owns the result.
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }
    }

    nonisolated private static func consumeFrames(
        camera: CameraCaptureSession,
        publish: @escaping @MainActor @Sendable (FrameHUDSnapshot) -> Void
    ) async {
        var iterator = camera.frameStream.frames.makeAsyncIterator()
        let clock = ContinuousClock()
        var lastPublication = clock.now - .seconds(3)

        while !Task.isCancelled, let frame = await iterator.next() {
            let now = clock.now
            guard lastPublication.duration(to: now) >= .seconds(2) else { continue }
            lastPublication = now

            let snapshot = FrameHUDSnapshot(
                diagnostics: LibraryDeliveredFrameDiagnostics(
                    frameID: frame.id.rawValue,
                    cameraPosition: frame.geometry.cameraPosition,
                    pixelWidth: frame.geometry.pixelWidth,
                    pixelHeight: frame.geometry.pixelHeight,
                    appliedVideoRotationAngle: frame.geometry.appliedVideoRotationAngle,
                    isMirrored: frame.geometry.isMirrored
                ),
                statistics: camera.frameStream.statistics()
            )
            await publish(snapshot)
        }
    }

    private func apply(_ snapshot: FrameHUDSnapshot) {
        deliveredFrameDiagnostics = snapshot.diagnostics
        frameSummary = "\(snapshot.diagnostics.pixelWidth) × \(snapshot.diagnostics.pixelHeight) px  •  frame \(snapshot.diagnostics.frameID)"
        statistics = snapshot.statistics
        librarySessionDiagnostics = makeLibrarySessionDiagnostics()
    }

    private func makeLibrarySessionDiagnostics() -> LibrarySessionDiagnostics? {
        guard let device = camera.activeCaptureDevice else { return nil }

        let dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
        let analysisConnection = camera.frameStream.output.connection(with: .video)
        let photoConnection = camera.photoOutput.connection(with: .video)

        return LibrarySessionDiagnostics(
            deviceType: state.deviceTypeRawValue,
            activeFormatWidth: Int(dimensions.width),
            activeFormatHeight: Int(dimensions.height),
            analysisConnectionRotationAngle: analysisConnection?.videoRotationAngle,
            analysisMirrored: analysisConnection?.isVideoMirrored,
            photoConnectionRotationAngle: photoConnection?.videoRotationAngle,
            photoMirrored: photoConnection?.isVideoMirrored
        )
    }
}
