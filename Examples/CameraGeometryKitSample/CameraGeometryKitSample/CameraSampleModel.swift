import AVFoundation
import CameraGeometryKit
import Foundation
import SwiftUI

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
            errorMessage = nil

            var iterator = camera.frameStream.frames.makeAsyncIterator()
            while !Task.isCancelled, let frame = await iterator.next() {
                // This sample displays metadata only. Pixel-buffer processing belongs
                // in a worker such as CameraVisionWorker, away from the UI actor.
                if frame.id.rawValue % 3 == 0 {
                    frameSummary = "\(frame.geometry.pixelWidth) × \(frame.geometry.pixelHeight) px  •  frame \(frame.id.rawValue)"
                    statistics = camera.frameStream.statistics()
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
        }
    }

    func switchCamera(to position: CameraPosition) async {
        guard isRunning, state.cameraPosition != position else { return }

        do {
            let nextState = try await camera.setCameraPosition(position)
            guard !Task.isCancelled else { return }
            state = nextState
            errorMessage = nil
        } catch is CancellationError {
            // A newer position request owns the result.
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }
    }
}
