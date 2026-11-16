import XCTest
@testable import PetCore

final class StarDefenseTests: XCTestCase {
    func testPlacingSpendsCashAndASlotOnlyOnce() {
        var field = StarDefense.field(for: 1)
        let placed = StarDefense.place(.dart, slot: 2, on: field)
        XCTAssertEqual(placed?.cash, field.cash - DefenseTowerKind.dart.cost)
        XCTAssertEqual(placed?.towers.count, 1)
        XCTAssertNil(StarDefense.place(.dart, slot: 2, on: placed!))
        field.cash = 10
        XCTAssertNil(StarDefense.place(.laser, slot: 0, on: field))
    }

    func testAnUpgradeFollowsOnePathAndPopsALayer() {
        var field = StarDefense.field(for: 1)
        field = StarDefense.place(.dart, slot: 0, on: field)!
        let id = field.towers[0].id
        field.cash = 200
        field = StarDefense.upgrade(tower: id, pathA: true, on: field)!
        XCTAssertEqual(field.towers[0].pathA, 1)
        XCTAssertNil(StarDefense.upgrade(tower: id, pathA: false, on: field))
        field.critters = [DefenseCritter(id: 9, layers: 3, distance: 8)]
        field.towers[0].cooldown = 0
        field.running = true
        field.queue = [1]
        let after = StarDefense.step(field, dt: 0.05)
        XCTAssertEqual(after.critters.first?.layers, 1)
        XCTAssertGreaterThan(after.cash, field.cash - 1)
    }

    func testALeakCostsALifeAndAClearWaveAdvances() {
        var field = StarDefense.field(for: 1)
        field.running = true
        field.critters = [DefenseCritter(id: 1, layers: 1, distance: 99)]
        let leaked = StarDefense.step(field, dt: 0.2)
        XCTAssertEqual(leaked.lives, field.lives - 1)
        var empty = StarDefense.field(for: 1)
        empty.running = true
        empty.queue = []
        empty.critters = []
        let cleared = StarDefense.step(empty, dt: 0.1)
        XCTAssertFalse(cleared.running)
        XCTAssertEqual(cleared.round, 2)
    }

    func testTheFirstMapIsOpenAndTheNextWaitsForAStar() {
        XCTAssertTrue(StarDefense.isOpen(level: 1, petLevel: 1, stars: [:]))
        XCTAssertFalse(StarDefense.isOpen(level: 2, petLevel: 5, stars: [:]))
        XCTAssertTrue(StarDefense.isOpen(level: 2, petLevel: 5, stars: [1: 1]))
        XCTAssertFalse(StarDefense.isOpen(level: 5, petLevel: 1, stars: [4: 3]))
        XCTAssertEqual(StarDefense.stars(lives: 20, livesAtStart: 20, won: true), 3)
        XCTAssertEqual(StarDefense.stars(lives: 1, livesAtStart: 20, won: true), 1)
        XCTAssertEqual(StarDefense.stars(lives: 10, livesAtStart: 20, won: false), 0)
    }

    func testARoundSpawnsTheQueuedCritters() {
        var field = StarDefense.beginRound(StarDefense.field(for: 1))
        XCTAssertFalse(field.queue.isEmpty)
        XCTAssertTrue(field.running)
        for _ in 0..<40 {
            field = StarDefense.step(field, dt: 0.6)
            if field.lost { break }
        }
        XCTAssertTrue(field.critters.isEmpty || field.lost || field.lives < field.livesAtStart)
    }
}
