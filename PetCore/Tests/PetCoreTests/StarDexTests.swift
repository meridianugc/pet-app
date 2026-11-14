import XCTest
@testable import PetCore

final class StarDexTests: XCTestCase {
    func testANewAlbumIsMostlySilhouettes() {
        let status = StarDex.status(collection: .empty, progress: PlayerProgress())
        let starters = LookBook.options.filter { PlayerProgress().wardrobe.owned.contains($0.id) }
        XCTAssertEqual(status.found, starters.count)
        XCTAssertEqual(status.total, StarDex.entries.count)
        XCTAssertEqual(status.fraction, Double(starters.count) / Double(status.total), accuracy: 0.001)
        XCTAssertFalse(StarDex.isFound(id: "form.star", collection: .empty, progress: PlayerProgress()))
    }

    func testRaisingFormsAndBuyingFillsTheDex() {
        var collection = PetCollection.empty
        collection.sawEgg = true
        collection.sawBaby = true
        collection.raisedForms = [.star, .cloud, .spiky]
        var progress = PlayerProgress(ownedIDs: ["outfit.scarf", "outfit.bow", "outfit.helmet"], gamesFinished: 1)
        for option in LookBook.options where !progress.wardrobe.owned.contains(option.id) {
            progress.wardrobe.owned.append(option.id)
        }
        var world = AwayWorld.fresh(at: Date(timeIntervalSince1970: 10))
        world.postcards = [Postcard(title: "A short hop", message: "Hi", at: Date(timeIntervalSince1970: 10), souvenir: "gems")]
        collection.letters = [HomeLetter(
            name: "Mochi",
            form: .star,
            age: "a day",
            wentHomeAt: Date(timeIntervalSince1970: 10),
            message: "Hi",
            trait: InheritedTrait(tint: .starlight, fromName: "Mochi")
        )]
        let status = StarDex.status(collection: collection, progress: progress, world: world)
        XCTAssertEqual(status.found, status.total)
        XCTAssertEqual(status.completedSets, ["Forms", "Looks", "Outfits", "Stickers"])
        let claimed = StarDex.claim(setName: "Forms", progress: progress, collection: collection)
        XCTAssertEqual(claimed?.1, 30)
        XCTAssertEqual(claimed?.0.coins, 30)
        XCTAssertNil(StarDex.claim(setName: "Forms", progress: claimed!.0, collection: collection))
    }

    func testAnIncompleteSetPaysNothing() {
        var collection = PetCollection.empty
        collection.sawEgg = true
        XCTAssertNil(StarDex.claim(setName: "Forms", progress: PlayerProgress(), collection: collection))
        XCTAssertTrue(StarDex.isFound(id: "form.egg", collection: collection, progress: PlayerProgress()))
    }
}
