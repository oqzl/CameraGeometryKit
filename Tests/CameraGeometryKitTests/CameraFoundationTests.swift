import AVFoundation
import XCTest
@testable import CameraGeometryKit

final class CameraFoundationTests: XCTestCase {
    func testCaptureSessionStartsUnconfigured() {
        let camera = CameraCaptureSession()
        let state = camera.currentState
        XCTAssertFalse(state.isConfigured)
        XCTAssertFalse(state.isRunning)
        XCTAssertEqual(state.cameraPosition, .unspecified)
        XCTAssertNil(state.deviceUniqueID)
        XCTAssertNil(state.deviceTypeRawValue)
        XCTAssertFalse(state.supportsDepthData)
        XCTAssertFalse(state.depthCaptureEnabled)
    }

    func testWideAngleRequestKeepsPositionAndDeviceType() {
        let request = CameraDeviceRequest.wideAngle(position: .front)
        XCTAssertEqual(request.position, .front)
        XCTAssertEqual(
            request.preferredDeviceTypes.map { $0.rawValue },
            [AVCaptureDevice.DeviceType.builtInWideAngleCamera.rawValue]
        )
    }

    func testDeviceRequestKeepsPreferenceOrderWhenPositionChanges() {
        let request = CameraDeviceRequest(
            position: .front,
            preferredDeviceTypes: [
                .builtInTrueDepthCamera,
                .builtInWideAngleCamera,
            ]
        )
        let back = request.withPosition(.back)

        XCTAssertEqual(back.position, .back)
        XCTAssertEqual(
            back.preferredDeviceTypes.map { $0.rawValue },
            request.preferredDeviceTypes.map { $0.rawValue }
        )
    }

    func testDepthConfigurationPrefersFloat32ThenFloat16ByDefault() {
        let configuration = CameraDepthConfiguration()
        XCTAssertEqual(
            configuration.preferredPixelFormatTypes,
            [kCVPixelFormatType_DepthFloat32, kCVPixelFormatType_DepthFloat16]
        )
        XCTAssertFalse(configuration.isFilteringEnabled)
    }

    func testVisionWorkerInvalidationAdvancesGeneration() async {
        let worker = CameraVisionWorker<Int>(
            operation: { _ in 0 },
            delivery: { _ in }
        )
        let initial = await worker.currentGeneration
        XCTAssertEqual(initial, 0)
        await worker.invalidate()
        let next = await worker.currentGeneration
        XCTAssertEqual(next, 1)
    }
}
