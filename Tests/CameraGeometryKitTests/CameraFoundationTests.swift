import Vision
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

    func testVisionWorkerInvalidationAdvancesGeneration() {
        let worker = CameraVisionWorker<Int>(
            makeRequest: { VNDetectFaceRectanglesRequest() },
            extract: { _ in 0 },
            delivery: { _ in }
        )

        XCTAssertEqual(worker.currentGeneration, 0)
        worker.invalidate()
        XCTAssertEqual(worker.currentGeneration, 1)
        worker.invalidate()
        XCTAssertEqual(worker.currentGeneration, 2)
    }
}
