import XCTest
@testable import PetCore

final class GameRewardTests: XCTestCase {
    func testStarCatchScoreAvoidsRocks() {
        XCTAssertEqual(GameRewards.starCatchPoints(stars: 3, snacks: 2, rocks: 1), 6)
        XCTAssertEqual(GameRewards.starCatchPoints(stars: 0, snacks: 1, rocks: 4), 0)
    }

    func testMemoryAndHideScores() {
        XCTAssertEqual(GameRewards.memoryPoints(pairs: 3, misses: 2), 7)
        XCTAssertEqual(GameRewards.memoryPoints(pairs: 0, misses: 5), 0)
        XCTAssertEqual(GameRewards.hideAndSeekPoints(finds: 2), 8)
    }

    func testRewardPaysCoinsHappinessAndEnergy() {
        let reward = GameRewards.reward(points: 4)
        XCTAssertEqual(reward.coins, 4)
        XCTAssertEqual(reward.happiness, 16, accuracy: 0.001)
        XCTAssertEqual(reward.energyCost, 14, accuracy: 0.001)
        XCTAssertEqual(reward.xp, 10)
    }

    func testRewardCapsAHugeScore() {
        let reward = GameRewards.reward(points: 100)
        XCTAssertEqual(reward.coins, 30)
        XCTAssertEqual(reward.happiness, 28, accuracy: 0.001)
    }

    func testAScoreOfZeroStillGivesALittleJoy() {
        let reward = GameRewards.reward(points: 0)
        XCTAssertEqual(reward.coins, 0)
        XCTAssertEqual(reward.happiness, 8, accuracy: 0.001)
        XCTAssertEqual(reward.xp, 6)
    }
}
