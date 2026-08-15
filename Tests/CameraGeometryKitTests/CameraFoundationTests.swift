import AVFoundation
import CoreVideo
import UIKit
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
        XCTAssertNil(camera.synchronizedFrameStream)
    }

    func testDepthCaptureCreatesSynchronizedStream() {
        let camera = CameraCaptureSession(
            depthConfiguration: CameraDepthCaptureConfiguration()
        )
        XCTAssertNotNil(camera.synchronizedFrameStream)
    }

    func testDepthConfigurationDefaults() {
        let configuration = CameraDepthCaptureConfiguration()
        XCTAssertFalse(configuration.isFilteringEnabled)
        XCTAssertEqual(
            configuration.preferredDepthDataTypes,
            [kCVPixelFormatType_DepthFloat32, kCVPixelFormatType_DepthFloat16]
        )
    }

    func testDeviceRequestPreservesPreferenceOrder() {
        let request = CameraDeviceRequest(
            position: .back,
            preferredDeviceTypes: [
                .builtInUltraWideCamera,
                .builtInWideAngleCamera,
            ]
        )
        XCTAssertNil(request.uniqueID)
        XCTAssertEqual(request.position, .back)
        XCTAssertEqual(
            request.preferredDeviceTypes.map(\.rawValue),
            [
                AVCaptureDevice.DeviceType.builtInUltraWideCamera.rawValue,
                AVCaptureDevice.DeviceType.builtInWideAngleCamera.rawValue,
            ]
        )
    }

    func testDeviceInfoCreatesExactRequest() {
        let device = CameraDeviceInfo(
            uniqueID: "camera-id",
            localizedName: "Back Wide",
            deviceType: .builtInWideAngleCamera,
            position: .back,
            supportsDepthData: false,
            minZoomFactor: 1,
            maxZoomFactor: 8
        )

        let request = CameraDeviceRequest(device: device)

        XCTAssertEqual(request.uniqueID, "camera-id")
        XCTAssertEqual(request.position, .back)
        XCTAssertEqual(request.preferredDeviceTypes, [.builtInWideAngleCamera])
        XCTAssertEqual(device.deviceTypeRawValue, AVCaptureDevice.DeviceType.builtInWideAngleCamera.rawValue)
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
