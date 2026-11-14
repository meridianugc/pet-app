import XCTest
@testable import PetCore

final class SnackMatchTests: XCTestCase {
    func testThreeInARowAreAMatchAndAPairIsNot() {
        let cells = [
            1, 1, 1, 0,
            2, 3, 2, 4
        ]
        let matched = SnackMatch.matchedIndexes(in: cells, width: 4, height: 2)
        XCTAssertEqual(matched, [0, 1, 2])
        XCTAssertTrue(SnackMatch.matchedIndexes(in: [0, 1, 0, 1], width: 4, height: 1).isEmpty)
    }

    func testOnlyNeighborsCanSwap() {
        XCTAssertTrue(SnackMatch.areNeighbors(0, 1, width: 3))
        XCTAssertTrue(SnackMatch.areNeighbors(1, 4, width: 3))
        XCTAssertFalse(SnackMatch.areNeighbors(0, 2, width: 3))
    }

    func testASwapThatMatchesClearsAndDrops() {
        let cells = [
            0, 1, 2,
            1, 0, 1,
            1, 1, 2
        ]
        var fills = [4, 4]
        let outcome = SnackMatch.swapAndResolve(cells: cells, width: 3, height: 3, a: 4, b: 7) {
            let next = fills.isEmpty ? 3 : fills.removeFirst()
            return next
        }
        XCTAssertNotNil(outcome)
        XCTAssertGreaterThan(outcome?.points ?? 0, 0)
        XCTAssertGreaterThan(outcome?.cascades ?? 0, 0)
    }

    func testAUselessSwapIsRejected() {
        let cells = [
            0, 1, 2,
            2, 0, 1,
            1, 2, 0
        ]
        let outcome = SnackMatch.swapAndResolve(cells: cells, width: 3, height: 3, a: 0, b: 1) { 4 }
        XCTAssertNil(outcome)
    }

    func testFourInARowPaysABonus() {
        XCTAssertEqual(SnackMatch.points(forClearing: 4, lineLength: 4), 32)
        XCTAssertEqual(SnackMatch.points(forClearing: 3, lineLength: 3), 15)
        XCTAssertEqual(SnackMatch.points(forClearing: 5, lineLength: 5), 55)
    }
}
