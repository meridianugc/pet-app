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

    func testRewardPaysGemsHappinessAndEnergy() {
        let reward = GameRewards.reward(points: 6)
        XCTAssertEqual(GameRewards.gems(forPoints: 6), 3)
        XCTAssertEqual(reward.coins, 3)
        XCTAssertEqual(reward.happiness, 11, accuracy: 0.001)
        XCTAssertEqual(reward.energyCost, 12, accuracy: 0.001)
        XCTAssertEqual(reward.xp, 14)
    }

    func testRewardCapsAHugeScore() {
        let reward = GameRewards.reward(points: 10_000)
        XCTAssertEqual(reward.coins, 24)
        XCTAssertEqual(reward.happiness, 30, accuracy: 0.001)
    }

    func testASoloGameWhileAsleepDoesNotTireThem() {
        let reward = GameRewards.reward(points: 6, solo: true)
        XCTAssertEqual(reward.coins, 3)
        XCTAssertEqual(reward.happiness, 0, accuracy: 0.001)
        XCTAssertEqual(reward.energyCost, 0, accuracy: 0.001)
        XCTAssertEqual(reward.xp, 14)
    }

    func testAScoreOfZeroStillGivesALittleJoy() {
        let reward = GameRewards.reward(points: 0)
        XCTAssertEqual(reward.coins, 0)
        XCTAssertEqual(reward.happiness, 8, accuracy: 0.001)
        XCTAssertEqual(reward.xp, 8)
    }
}
