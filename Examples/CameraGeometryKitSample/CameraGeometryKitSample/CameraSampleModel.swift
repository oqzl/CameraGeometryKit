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

struct LibraryDeliveredFrameDiagnostics: Equatable {
    let frameID: UInt64
    let cameraPosition: CameraPosition
    let pixelWidth: Int
    let pixelHeight: Int
    let appliedVideoRotationAngle: CGFloat
    let isMirrored: Bool
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

    let camera = CameraCaptureSession(sessionPreset: .high)

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

            var iterator = camera.frameStream.frames.makeAsyncIterator()
            while !Task.isCancelled, let frame = await iterator.next() {
                // Keep the HUD useful without publishing the entire SwiftUI tree
                // for every captured frame.
                if frame.id.rawValue % 3 == 0 {
                    deliveredFrameDiagnostics = LibraryDeliveredFrameDiagnostics(
                        frameID: frame.id.rawValue,
                        cameraPosition: frame.geometry.cameraPosition,
                        pixelWidth: frame.geometry.pixelWidth,
                        pixelHeight: frame.geometry.pixelHeight,
                        appliedVideoRotationAngle: frame.geometry.appliedVideoRotationAngle,
                        isMirrored: frame.geometry.isMirrored
                    )
                    frameSummary = "\(frame.geometry.pixelWidth) × \(frame.geometry.pixelHeight) px  •  frame \(frame.id.rawValue)"
                    statistics = camera.frameStream.statistics()
                    librarySessionDiagnostics = makeLibrarySessionDiagnostics()
                }
            }
        } catch is CancellationError {
            // The view-bound task is expected to be cancelled when the screen leaves.
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
