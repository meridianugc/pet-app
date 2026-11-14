import XCTest
@testable import PetCore

final class ShopTests: XCTestCase {
    func testFoodPurchaseMovesCoinsIntoThePantry() {
        let progress = PlayerProgress(coins: 20, xp: 0)
        let bought = Shop.purchase(id: "food.starBerry", progress: progress, level: 1)
        guard case let .success(next) = bought else {
            return XCTFail("expected a purchase")
        }
        XCTAssertEqual(next.coins, 12)
        XCTAssertEqual(next.stock["food.starBerry"], 1)
    }

    func testPurchaseRejectsAShortWalletAndALockedLevel() {
        let poor = Shop.purchase(id: "food.moonCookie", progress: PlayerProgress(coins: 5), level: 5)
        XCTAssertEqual(poor, .failure(.notEnoughCoins(have: 5, need: 20)))
        let locked = Shop.purchase(id: "food.moonCookie", progress: PlayerProgress(coins: 50), level: 1)
        XCTAssertEqual(locked, .failure(.levelLocked(required: 3)))
        XCTAssertEqual(Shop.purchase(id: "nope", progress: PlayerProgress(coins: 50), level: 9), .failure(.unknownItem))
    }

    func testOutfitsCannotBeBoughtTwiceAndMustBeOwnedToWear() {
        var progress = PlayerProgress(coins: 100)
        progress = tryResult(Shop.purchase(id: "outfit.scarf", progress: progress, level: 1))
        XCTAssertEqual(Shop.purchase(id: "outfit.scarf", progress: progress, level: 1), .failure(.alreadyOwned))
        XCTAssertEqual(Shop.equip("outfit.bow", progress: progress), .failure(.noneLeft))
        let worn = tryResult(Shop.equip("outfit.scarf", progress: progress))
        XCTAssertEqual(worn.outfitID, "outfit.scarf")
        XCTAssertNil(tryResult(Shop.equip(nil, progress: worn)).outfitID)
    }

    func testCloudPuffCountsAsATreatWhileABaby() {
        var progress = PlayerProgress(coins: 30)
        progress = tryResult(Shop.purchase(id: "food.cloudPuff", progress: progress, level: 1))
        let used = Shop.consume(id: "food.cloudPuff", progress: progress)
        guard case let .success((next, effect)) = used else { return XCTFail("expected a puff") }
        XCTAssertEqual(next.stock["food.cloudPuff"], nil)
        XCTAssertTrue(effect.countsAsTreat)
        var baby = Pet.freshEgg(name: "Pip", at: Date(timeIntervalSince1970: 10))
        baby.stage = .baby
        baby.hunger = 40
        let fed = PetCare.apply(effect, to: baby)
        XCTAssertEqual(fed.care.overfeeds, 1)
        XCTAssertEqual(fed.hunger, 56, accuracy: 0.001)
        if case .failure(.noneLeft) = Shop.consume(id: "food.cloudPuff", progress: next) {
        } else {
            XCTFail("expected an empty pantry")
        }
    }

    func testStarBerryIsAHealthyMeal() {
        let progress = tryResult(Shop.purchase(id: "food.starBerry", progress: PlayerProgress(coins: 8), level: 1))
        guard case let .success((_, effect)) = Shop.consume(id: "food.starBerry", progress: progress) else {
            return XCTFail("expected a berry")
        }
        XCTAssertTrue(effect.countsAsHealthyMeal)
        XCTAssertFalse(effect.countsAsTreat)
    }

    private func tryResult<T>(_ result: Result<T, ShopError>) -> T {
        guard case let .success(value) = result else {
            XCTFail("expected success")
            fatalError("test helper")
        }
        return value
    }
}
