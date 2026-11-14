import XCTest
@testable import PetCore

final class EvolutionTests: XCTestCase {
    func testNoCareBecomesSpiky() {
        XCTAssertEqual(Evolution.form(for: CareHistory()), .spiky)
    }

    func testLongEmptyNeedsBecomeSpikyEvenAfterMeals() {
        let care = CareHistory(properFeeds: 4, plays: 2, hungerEmptySeconds: 2 * 60 * 60)
        XCTAssertEqual(Evolution.form(for: care), .spiky)
    }

    func testNeglectJustUnderTheLineCanStillBeAStar() {
        let care = CareHistory(
            properFeeds: 3,
            plays: 2,
            hungerEmptySeconds: (2 * 60 * 60) - 1
        )
        XCTAssertEqual(Evolution.form(for: care), .star)
    }

    func testThreeTreatsBecomeACloud() {
        let care = CareHistory(properFeeds: 1, overfeeds: 3, plays: 1)
        XCTAssertEqual(Evolution.form(for: care), .cloud)
    }

    func testPlayWithoutSteadyMealsBecomesACloud() {
        let care = CareHistory(properFeeds: 1, plays: 5)
        XCTAssertEqual(Evolution.form(for: care), .cloud)
    }

    func testBalancedMealsAndPlayBecomeAStar() {
        let care = CareHistory(properFeeds: 3, overfeeds: 1, plays: 2, happinessEmptySeconds: 10 * 60)
        XCTAssertEqual(Evolution.form(for: care), .star)
    }

    func testSpikyWinsWhenTheyWereBothSpoiledAndNeglected() {
        let care = CareHistory(overfeeds: 5, plays: 6, hungerEmptySeconds: 3 * 60 * 60)
        XCTAssertEqual(Evolution.form(for: care), .spiky)
    }

    func testALowLevelCannotGrowIntoALaterForm() {
        let cared = CareHistory(properFeeds: 4, plays: 2)
        XCTAssertEqual(Evolution.form(for: cared), .star)
        XCTAssertEqual(Evolution.form(for: cared, level: 6), .star)
        XCTAssertEqual(Evolution.form(for: cared, level: 3), .spiky)
        XCTAssertEqual(Evolution.form(for: cared, level: 1), .star)
        XCTAssertEqual(AdultForm.cloud.unlockLevel, 4)
        XCTAssertTrue(StarDex.entries.allSatisfy { $0.unlockLevel >= 1 })
    }
}
