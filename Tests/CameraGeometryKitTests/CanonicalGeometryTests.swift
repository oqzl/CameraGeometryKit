import CoreGraphics
import Vision
import XCTest
@testable import CameraGeometryKit

final class CanonicalGeometryTests: XCTestCase {
    func testVisionRectRoundTrip() {
        let input = NormalizedRect(x: 0.2, y: 0.1, width: 0.4, height: 0.3)
        let canonical = VisionGeometry.canonicalRect(from: input)
        XCTAssertEqual(canonical.y, 0.6, accuracy: 0.000_001)
        XCTAssertEqual(VisionGeometry.normalizedRect(from: canonical), input)
    }

    func testVisionPointRoundTrip() {
        let input = NormalizedPoint(x: 0.25, y: 0.75)
        let canonical = VisionGeometry.canonicalPoint(from: input)
        XCTAssertEqual(canonical.x, 0.25, accuracy: 0.000_001)
        XCTAssertEqual(canonical.y, 0.25, accuracy: 0.000_001)
        XCTAssertEqual(VisionGeometry.normalizedPoint(from: canonical), input)
    }

    func testAspectFitRejectsLetterboxTouch() {
        let mapping = ViewportMapping(
            imageSize: CGSize(width: 400, height: 300),
            viewportSize: CGSize(width: 400, height: 800),
            contentMode: .aspectFit
        )
        XCTAssertNil(mapping.canonicalPoint(fromViewport: CGPoint(x: 200, y: 20)))
    }
}
