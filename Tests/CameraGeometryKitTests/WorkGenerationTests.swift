import XCTest
@testable import CameraGeometryKit

final class WorkGenerationTests: XCTestCase {
    func testInvalidateAdvancesGeneration() {
        let generation = WorkGeneration()
        let initial = generation.current

        let next = generation.invalidate()

        XCTAssertEqual(initial, 0)
        XCTAssertEqual(next, 1)
        XCTAssertFalse(generation.isCurrent(initial))
        XCTAssertTrue(generation.isCurrent(next))
    }
}
