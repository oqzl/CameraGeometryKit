import Vision
import XCTest
@testable import CameraGeometryKit

final class SwiftVisionAPITests: XCTestCase {
    func testFaceRequestMapsNormalizedGeometry() async {
        let worker = CameraVisionWorker<[CanonicalRect]>(
            makeRequest: { DetectFaceRectanglesRequest() },
            map: { observations in
                observations.map { VisionGeometry.canonicalRect(from: $0.boundingBox) }
            },
            delivery: { _ in }
        )

        let generation = await worker.currentGeneration
        XCTAssertEqual(generation, 0)
    }
}
