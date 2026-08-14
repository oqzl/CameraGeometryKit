import AVFoundation
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
    }

    func testDeviceRequestPreservesPreferenceOrder() {
        let request = CameraDeviceRequest(
            position: .back,
            preferredDeviceTypes: [
                .builtInUltraWideCamera,
                .builtInWideAngleCamera,
            ]
        )
        XCTAssertEqual(request.position, .back)
        XCTAssertEqual(
            request.preferredDeviceTypes.map(\.rawValue),
            [
                AVCaptureDevice.DeviceType.builtInUltraWideCamera.rawValue,
                AVCaptureDevice.DeviceType.builtInWideAngleCamera.rawValue,
            ]
        )
    }

    func testARKitCanonicalPixelSize() {
        let raw = CGSize(width: 1920, height: 1440)
        XCTAssertEqual(
            ARKitFrameAdapter.canonicalPixelSize(
                rawPixelSize: raw,
                interfaceOrientation: .portrait
            ),
            CGSize(width: 1440, height: 1920)
        )
        XCTAssertEqual(
            ARKitFrameAdapter.canonicalPixelSize(
                rawPixelSize: raw,
                interfaceOrientation: .landscapeRight
            ),
            raw
        )
    }

    func testARKitGeometryRemovesPresentationMirror() {
        let mirror = CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 1, ty: 0)
        let geometry = ARKitFrameGeometry(
            rawPixelSize: CGSize(width: 1920, height: 1440),
            canonicalPixelSize: CGSize(width: 1920, height: 1440),
            rawToPresentedNormalized: mirror
        )
        XCTAssertTrue(geometry.presentationIsMirrored)
        let canonical = geometry.canonicalPoint(
            fromARKitNormalized: CGPoint(x: 0.2, y: 0.4)
        )
        XCTAssertEqual(canonical.x, 0.2, accuracy: 0.0001)
        XCTAssertEqual(canonical.y, 0.4, accuracy: 0.0001)
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
