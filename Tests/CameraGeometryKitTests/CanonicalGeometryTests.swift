import CoreGraphics
import XCTest
@testable import CameraGeometryKit

final class CanonicalGeometryTests: XCTestCase {
    func testVisionRectRoundTrip() {
        let input = CGRect(x: 0.2, y: 0.1, width: 0.4, height: 0.3)
        let canonical = VisionGeometry.canonicalRect(fromVisionNormalized: input)
        XCTAssertEqual(canonical.y, 0.6, accuracy: 0.000_001)
        XCTAssertEqual(VisionGeometry.visionNormalizedRect(from: canonical), input)
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
