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
        XCTAssertFalse(outcome?.steps.isEmpty ?? true)
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

    func testABoardWithNoSwapHasNoHintAndASmashDropsTheColumn() {
        let stuck = [
            0, 1, 2,
            2, 0, 1,
            1, 2, 0
        ]
        XCTAssertFalse(SnackMatch.hasMove(in: stuck, width: 3, height: 3))
        XCTAssertNil(SnackMatch.hint(in: stuck, width: 3, height: 3))
        let smashed = SnackMatch.smash(cells: [1, 1, 2, 0, 3, 4], width: 3, height: 2, index: 0) { 9 }
        XCTAssertEqual(smashed?.cells[0], 9)
        let cleared = SnackMatch.clearColor(cells: [1, 2, 1, 1], width: 2, height: 2, hue: 1) { 4 }
        XCTAssertFalse(cleared?.cells.contains(1) ?? true)
    }

    func testTheSameSeedReshufflesTheSameWay() {
        let cells = [0, 1, 2, 3, 4, 0, 1, 2]
        let first = SnackMatch.reshuffled(cells, width: 4, height: 2, seed: 9)
        let second = SnackMatch.reshuffled(cells, width: 4, height: 2, seed: 9)
        XCTAssertEqual(first, second)
    }

    func testChargesRefillFromTheClockAndCanBeBought() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        var pouch = PowerPouch(slots: ["hammer": PowerCharge(count: 0, updatedAt: start)])
        XCTAssertEqual(pouch.count(.hammer, now: start), 0)
        XCTAssertEqual(pouch.count(.hammer, now: start.addingTimeInterval(30 * 60)), 2)
        XCTAssertNil(pouch.spending(.hammer, now: start))
        let bought = pouch.buying(.hammer, coins: 20, now: start)
        XCTAssertEqual(bought?.0.count(.hammer, now: start), 1)
        XCTAssertEqual(bought?.1, 12)
        let full = PowerPouch.stocked(at: start)
        XCTAssertNil(full.buying(.hammer, coins: 50, now: start))
        XCTAssertEqual(full.spending(.jet, now: start)?.count(.jet, now: start), 2)
    }

    func testFourInARowPaysABonus() {
        XCTAssertEqual(SnackMatch.points(forClearing: 4, lineLength: 4), 32)
        XCTAssertEqual(SnackMatch.points(forClearing: 3, lineLength: 3), 15)
        XCTAssertEqual(SnackMatch.points(forClearing: 5, lineLength: 5), 55)
    }
}
