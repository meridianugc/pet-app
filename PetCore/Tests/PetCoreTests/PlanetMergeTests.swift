import XCTest
@testable import PetCore

final class PlanetMergeTests: XCTestCase {
    func testPlanetsMergeUpToALargestSize() {
        XCTAssertEqual(PlanetMerge.nextSize(after: 0), 1)
        XCTAssertEqual(PlanetMerge.nextSize(after: 5), 6)
        XCTAssertNil(PlanetMerge.nextSize(after: 6))
        XCTAssertNil(PlanetMerge.nextSize(after: -1))
    }

    func testComboMultipliesMergePoints() {
        XCTAssertEqual(PlanetMerge.points(forMerging: 0, combo: 1), 4)
        XCTAssertEqual(PlanetMerge.points(forMerging: 2, combo: 3), 36)
        XCTAssertEqual(PlanetMerge.points(forMerging: 1, combo: 0), 8)
    }

    func testBiggerPlanetsHaveBiggerRadii() {
        XCTAssertGreaterThan(PlanetMerge.radius(for: 3), PlanetMerge.radius(for: 1))
    }
}
