import XCTest
@testable import PetCore

final class LevelTests: XCTestCase {
    func testLevelThresholds() {
        XCTAssertEqual(LevelTable.level(for: 0), 1)
        XCTAssertEqual(LevelTable.level(for: 39), 1)
        XCTAssertEqual(LevelTable.xpToReach(2), 40)
        XCTAssertEqual(LevelTable.level(for: 40), 2)
        XCTAssertEqual(LevelTable.xpToReach(3), 100)
        XCTAssertEqual(LevelTable.level(for: 99), 2)
        XCTAssertEqual(LevelTable.level(for: 100), 3)
        XCTAssertEqual(LevelTable.level(for: -4), 1)
    }

    func testEvolutionBonusOnlyWhenTheyGrowUp() {
        var baby = Pet.freshEgg(name: "Pip", at: Date(timeIntervalSince1970: 10))
        baby.stage = .baby
        var adult = baby
        adult.stage = .adult
        adult.adultForm = .star
        XCTAssertTrue(EvolutionBonus.applies(before: baby, after: adult))
        XCTAssertFalse(EvolutionBonus.applies(before: adult, after: adult))
        XCTAssertEqual(EvolutionBonus.coins, 15)
        XCTAssertEqual(EvolutionBonus.xp, 25)
    }
}
