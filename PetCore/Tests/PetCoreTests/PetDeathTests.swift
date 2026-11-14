import XCTest
@testable import PetCore

final class PetDeathTests: XCTestCase {
    func testNeglectKillsAndCareClearsTheTimer() {
        let rules = EngineFixture.rules(hunger: 0, happiness: 0, energy: 0, neglect: 4 * 3600)
        let engine = PetEngine(rules: rules)
        var pet = EngineFixture.baby(rules: rules, hunger: 0, happiness: 40, energy: 50)
        pet.criticalSince = EngineFixture.start
        pet.lastSimulatedAt = EngineFixture.start

        let still = engine.advance(pet, to: EngineFixture.start.addingTimeInterval(3 * 3600))
        XCTAssertFalse(still.hasGoneHome)
        XCTAssertEqual(still.criticalSince, EngineFixture.start)

        let gone = engine.advance(pet, to: EngineFixture.start.addingTimeInterval(4 * 3600))
        XCTAssertTrue(gone.hasGoneHome)
        XCTAssertEqual(gone.wentHomeAt, EngineFixture.start.addingTimeInterval(4 * 3600))
        XCTAssertEqual(gone.homeReason, .hunger)
        XCTAssertEqual(gone.lastSimulatedAt, gone.wentHomeAt)

        let later = engine.advance(pet, to: EngineFixture.start.addingTimeInterval(9 * 3600))
        XCTAssertEqual(later.wentHomeAt, gone.wentHomeAt)
        XCTAssertEqual(later.hunger, gone.hunger, accuracy: 0.001)
        XCTAssertFalse(engine.perform(.feed, on: later, at: EngineFixture.start.addingTimeInterval(9 * 3600)).applied)

        var lonely = EngineFixture.baby(rules: rules, hunger: 40, happiness: 0, energy: 50)
        lonely.criticalSince = EngineFixture.start
        lonely.lastSimulatedAt = EngineFixture.start
        let lonelyDeath = engine.advance(lonely, to: EngineFixture.start.addingTimeInterval(4 * 3600))
        XCTAssertEqual(lonelyDeath.homeReason, .loneliness)

        let rescued = engine.perform(.feed, on: pet, at: EngineFixture.start.addingTimeInterval(30 * 60))
        XCTAssertTrue(rescued.applied)
        XCTAssertNil(rescued.pet.criticalSince)
        XCTAssertFalse(rescued.pet.hasGoneHome)
        let after = engine.advance(rescued.pet, to: EngineFixture.start.addingTimeInterval(10 * 3600))
        XCTAssertFalse(after.hasGoneHome)
    }

    func testStarvationStillKillsDuringSleepCycles() {
        var rules = EngineFixture.rules(
            hunger: 10,
            happiness: 0,
            energy: 100,
            sleepEnergy: 100,
            sleepHunger: 10,
            neglect: 2 * 3600
        )
        rules.happinessDecayPerHour = 0
        let engine = PetEngine(rules: rules)
        let pet = EngineFixture.baby(rules: rules, hunger: 30, happiness: 80, energy: 100)
        let origin = pet.lastSimulatedAt
        let before = engine.advance(pet, to: origin.addingTimeInterval(4 * 3600 + 3500))
        XCTAssertFalse(before.hasGoneHome)
        let dead = engine.advance(pet, to: origin.addingTimeInterval(5 * 3600))
        XCTAssertTrue(dead.hasGoneHome)
        XCTAssertEqual(dead.homeReason, .hunger)
    }
}
