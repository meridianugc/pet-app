import XCTest
@testable import PetCore

final class HopperCourseTests: XCTestCase {
    func testSameSeedBuildsTheSameCourse() {
        let first = HopperCourse.pads(seed: 42, count: 8)
        let second = HopperCourse.pads(seed: 42, count: 8)
        XCTAssertEqual(first, second)
        XCTAssertNotEqual(first, HopperCourse.pads(seed: 43, count: 8))
    }

    func testTheLaunchPadIsSteadyAndLaterPadsClimb() {
        let pads = HopperCourse.pads(seed: 7, count: 6, spacing: 100)
        XCTAssertEqual(pads.first?.kind, .steady)
        XCTAssertEqual(pads.first?.y, 0)
        XCTAssertEqual(pads[3].y, 300)
        XCTAssertTrue(pads.allSatisfy { $0.x >= 0.12 && $0.x < 0.88 })
    }

    func testAnEmptyRequestMakesNoPads() {
        XCTAssertTrue(HopperCourse.pads(seed: 1, count: 0).isEmpty)
    }
}
