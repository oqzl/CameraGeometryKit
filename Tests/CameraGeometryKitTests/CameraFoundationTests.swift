import AVFoundation
import CoreVideo
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

    func testAuxiliaryCaptureGraphMutationRequiresConfiguredSession() async {
        let camera = CameraCaptureSession()

        do {
            try await camera.setAudioCaptureDevice(nil)
            XCTFail("Expected setAudioCaptureDevice to reject an unconfigured session")
        } catch CameraCaptureSessionError.notConfigured {
            // Expected.
        } catch {
            XCTFail("Unexpected audio attachment error: \(error)")
        }

        do {
            try await camera.setMovieFileOutput(
                AVCaptureMovieFileOutput(),
                sessionPreset: .high
            )
            XCTFail("Expected setMovieFileOutput to reject an unconfigured session")
        } catch CameraCaptureSessionError.notConfigured {
            // Expected.
        } catch {
            XCTFail("Unexpected movie attachment error: \(error)")
        }
    }

    func testDepthCaptureReusesColorFrameOutput() throws {
        let camera = CameraCaptureSession(
            depthConfiguration: CameraDepthCaptureConfiguration()
        )
        let stream = try XCTUnwrap(camera.synchronizedFrameStream)

        XCTAssertTrue(stream.videoOutput === camera.frameStream.output)
        XCTAssertEqual(
            stream.statistics(),
            CameraSynchronizedFrameStreamStatistics(
                deliveredFrames: 0,
                droppedColorByAVFoundation: 0,
                droppedDepthByAVFoundation: 0,
                replacedInLatestBuffer: 0
            )
        )
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
            ],
            requiresDepthData: true
        )
        XCTAssertNil(request.uniqueID)
        XCTAssertTrue(request.requiresDepthData)
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
        XCTAssertFalse(request.requiresDepthData)
        XCTAssertEqual(
            device.deviceTypeRawValue,
            AVCaptureDevice.DeviceType.builtInWideAngleCamera.rawValue
        )
    }

    func testDepthRequirementCanBeAddedWithoutChangingDevicePreference() {
        let request = CameraDeviceRequest(
            position: .front,
            preferredDeviceTypes: [
                .builtInTrueDepthCamera,
                .builtInWideAngleCamera,
            ],
            uniqueID: "camera-id"
        )

        let depthRequest = request.requiringDepthData()

        XCTAssertEqual(depthRequest.uniqueID, request.uniqueID)
        XCTAssertEqual(depthRequest.position, request.position)
        XCTAssertEqual(depthRequest.preferredDeviceTypes, request.preferredDeviceTypes)
        XCTAssertTrue(depthRequest.requiresDepthData)
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
