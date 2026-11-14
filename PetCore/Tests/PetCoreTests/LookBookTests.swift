import XCTest
@testable import PetCore

final class LookBookTests: XCTestCase {
    func testAStripeShellCostsGemsAndAHeartAntennaNeedsATrip() {
        let bought = LookBook.buy(
            id: "shell.stripes",
            wardrobe: .plain,
            coins: 20,
            level: 1,
            achievements: []
        )
        guard case let .success((wardrobe, coins)) = bought else { return XCTFail("buy") }
        XCTAssertEqual(coins, 8)
        XCTAssertTrue(wardrobe.owned.contains("shell.stripes"))

        let blocked = LookBook.buy(
            id: "antenna.heart",
            wardrobe: .plain,
            coins: 40,
            level: 4,
            achievements: []
        )
        guard case .failure(.lockedTrips(1)) = blocked else { return XCTFail("expected a trip lock") }
        var traveled = Wardrobe.plain
        traveled.tripsFinished = 1
        XCTAssertNotNil(try? LookBook.buy(id: "antenna.heart", wardrobe: traveled, coins: 40, level: 4, achievements: []).get())
    }

    func testSoftEyesNeedTheFirstMealAndAStarMarkOnlyFitsAStar() {
        let locked = LookBook.buy(id: "eyes.soft", wardrobe: .plain, coins: 30, level: 2, achievements: [])
        guard case .failure(.lockedAchievement) = locked else { return XCTFail("expected an achievement lock") }
        let open = LookBook.buy(
            id: "eyes.soft",
            wardrobe: .plain,
            coins: 30,
            level: 2,
            achievements: [.firstMeal]
        )
        guard case let .success((wardrobe, _)) = open else { return XCTFail("eyes") }
        let worn = LookBook.wear(id: "eyes.soft", wardrobe: wardrobe, stage: .baby, form: nil)
        XCTAssertEqual(try? worn.get().eyes, "eyes.soft")

        var rich = Wardrobe.plain
        rich.owned.append("marking.belly")
        guard case .failure(.wrongStage) = LookBook.wear(id: "marking.belly", wardrobe: rich, stage: .baby, form: nil) else {
            return XCTFail("expected the wrong stage")
        }
        XCTAssertEqual(
            try? LookBook.wear(id: "marking.belly", wardrobe: rich, stage: .adult, form: .star).get().marking,
            "marking.belly"
        )
    }

    func testOldSavesGrowAPlainWardrobe() throws {
        let data = "{\"coins\":2}".data(using: .utf8)!
        let loaded = try JSONDecoder().decode(PlayerProgress.self, from: data)
        XCTAssertEqual(loaded.wardrobe.shell, "shell.plain")
        XCTAssertEqual(loaded.coins, 2)
    }
}
