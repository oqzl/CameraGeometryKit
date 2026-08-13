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
