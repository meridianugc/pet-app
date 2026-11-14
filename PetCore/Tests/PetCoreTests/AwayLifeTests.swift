import XCTest
@testable import PetCore

final class AwayLifeTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    func testSeedsGrowOverRealHoursAndHarvestPaysGems() {
        let planted = AwayLife.plant(AwayWorld.fresh(at: start), at: start)
        XCTAssertEqual(planted?.seeds.first?.stage(at: start), 0)
        XCTAssertEqual(planted?.seeds.first?.stage(at: start.addingTimeInterval(3600)), 1)
        XCTAssertEqual(planted?.seeds.first?.stage(at: start.addingTimeInterval(6 * 3600)), 3)
        let picked = AwayLife.harvest(planted!, at: start.addingTimeInterval(6 * 3600))
        XCTAssertEqual(picked?.1, 12)
        XCTAssertTrue(picked?.0.seeds.isEmpty ?? false)
        XCTAssertNil(AwayLife.harvest(planted!, at: start.addingTimeInterval(3600)))
    }

    func testATripComesHomeWithAPostcardAndTheTreeCaps() {
        let launched = AwayLife.launch(AwayWorld.fresh(at: start), hours: 4, at: start)
        XCTAssertNil(AwayLife.collectTrip(launched!, at: start.addingTimeInterval(3600)))
        let home = AwayLife.collectTrip(launched!, at: start.addingTimeInterval(4 * 3600))
        XCTAssertEqual(home?.1.title, "A quiet ring")
        XCTAssertEqual(home?.0.postcards.count, 1)
        XCTAssertNil(AwayLife.launch(launched!, hours: 1, at: start.addingTimeInterval(10)))
        var tree = AwayWorld.fresh(at: start)
        XCTAssertEqual(AwayLife.pendingGems(tree, at: start.addingTimeInterval(3 * 3600)), 6)
        XCTAssertEqual(AwayLife.pendingGems(tree, at: start.addingTimeInterval(40 * 3600)), AwayWorld.gemCap)
        let picked = AwayLife.collectTree(tree, at: start.addingTimeInterval(3 * 3600))
        XCTAssertEqual(picked.1, 6)
        XCTAssertEqual(AwayLife.pendingGems(picked.0, at: start.addingTimeInterval(3 * 3600)), 0)
        tree.treeAt = start
    }

    func testTimeAwayLeavesASummaryOnce() {
        let world = AwayWorld.fresh(at: start)
        let first = AwayLife.catchUp(world, at: start.addingTimeInterval(2 * 3600))
        XCTAssertFalse(first.1.lines.isEmpty)
        let second = AwayLife.catchUp(first.0, at: start.addingTimeInterval(2 * 3600 + 30))
        XCTAssertTrue(second.1.lines.isEmpty)
    }

    func testNeedsDecayMoreSlowlyOnATrip() {
        let rules = EngineFixture.rules(hunger: 10)
        let engine = PetEngine(rules: rules)
        var pet = EngineFixture.baby(rules: rules, hunger: 80)
        let later = pet.lastSimulatedAt.addingTimeInterval(3600)
        let full = engine.advance(pet, to: later)
        pet.hunger = 80
        let slow = engine.advance(pet, to: later, decayScale: 0.5)
        XCTAssertGreaterThan(slow.hunger, full.hunger)
    }
}
