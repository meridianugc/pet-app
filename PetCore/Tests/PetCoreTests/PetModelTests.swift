import XCTest
@testable import PetCore

final class PetModelTests: XCTestCase {
    func testFreshEggUsesAFallbackNameAndTrimsIt() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let blank = Pet.freshEgg(name: "   ", at: now)
        XCTAssertEqual(blank.name, "Mochi")
        let messy = Pet.freshEgg(name: "  Pip  ", at: now)
        XCTAssertEqual(messy.name, "Pip")
        let long = Pet.freshEgg(name: String(repeating: "a", count: 40), at: now)
        XCTAssertEqual(long.name.count, 24)
        XCTAssertEqual(blank.stage, .egg)
        XCTAssertFalse(blank.isDead)
    }

    func testStandardRulesMatchTheShippedPet() {
        let rules = PetRules()
        XCTAssertEqual(rules.eggDuration, 45 * 60)
        XCTAssertEqual(rules.babyDuration, 6 * 60 * 60)
        XCTAssertEqual(rules.evolution.spikyNeglectSeconds, 2 * 60 * 60)
        XCTAssertEqual(rules.evolution.cloudOverfeedCount, 3)
        XCTAssertEqual(rules.hungerDecayPerHour, 10)
        XCTAssertEqual(rules.happinessDecayPerHour, 7)
        XCTAssertEqual(rules.energyDecayPerHour, 12)
        XCTAssertEqual(rules.sleepEnergyPerHour, 30)
        XCTAssertEqual(rules.sleepHungerPerHour, 4)
        XCTAssertEqual(rules.sleepHappinessPerHour, 0)
        XCTAssertEqual(rules.neglectDuration, 4 * 60 * 60)
        XCTAssertEqual(rules.hatchHunger, 80)
        XCTAssertEqual(rules.hungerWarning, 30)
        XCTAssertEqual(rules.deathWarningLead, 45 * 60)
    }
}
