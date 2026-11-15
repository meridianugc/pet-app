import XCTest
@testable import PetCore

final class RoomClosetTests: XCTestCase {
    func testDraggingOntoThePetWearsItAndTheHangerTakesItBack() {
        var wardrobe = Wardrobe.plain
        wardrobe.owned.append("eyes.star")
        let pegs = RoomCloset.pegs(wardrobe: wardrobe, outfitID: nil, ownedIDs: ["outfit.scarf"])
        XCTAssertTrue(pegs.contains { $0.id == "eyes.star" && !$0.worn })
        XCTAssertTrue(pegs.contains { $0.id == "outfit.scarf" && !$0.worn })

        let missed = RoomCloset.dropOnPet(
            id: "eyes.star",
            at: RoomSpot(x: 0.1, y: 0.1),
            wardrobe: wardrobe,
            outfitID: nil,
            ownedIDs: ["outfit.scarf"],
            stage: .baby,
            form: nil
        )
        XCTAssertNil(missed)

        let worn = RoomCloset.dropOnPet(
            id: "eyes.star",
            at: RoomCloset.petSpot,
            wardrobe: wardrobe,
            outfitID: nil,
            ownedIDs: ["outfit.scarf"],
            stage: .baby,
            form: nil
        )
        XCTAssertEqual(worn?.wardrobe.eyes, "eyes.star")

        let scarf = RoomCloset.dropOnPet(
            id: "outfit.scarf",
            at: RoomCloset.petSpot,
            wardrobe: worn!.wardrobe,
            outfitID: nil,
            ownedIDs: ["outfit.scarf"],
            stage: .baby,
            form: nil
        )
        XCTAssertEqual(scarf?.outfitID, "outfit.scarf")

        let peg = RoomCloset.pegs(wardrobe: scarf!.wardrobe, outfitID: "outfit.scarf", ownedIDs: ["outfit.scarf"]).first { $0.id == "eyes.star" }!
        let back = RoomCloset.returnToPeg(
            id: "eyes.star",
            at: peg.spot,
            wardrobe: scarf!.wardrobe,
            outfitID: "outfit.scarf",
            ownedIDs: ["outfit.scarf"],
            stage: .baby,
            form: nil
        )
        XCTAssertEqual(back?.wardrobe.eyes, "eyes.round")
        let scarfPeg = RoomCloset.pegs(wardrobe: back!.wardrobe, outfitID: "outfit.scarf", ownedIDs: ["outfit.scarf"]).first { $0.id == "outfit.scarf" }!
        let off = RoomCloset.returnToPeg(
            id: "outfit.scarf",
            at: scarfPeg.spot,
            wardrobe: back!.wardrobe,
            outfitID: "outfit.scarf",
            ownedIDs: ["outfit.scarf"],
            stage: .baby,
            form: nil
        )
        XCTAssertNil(off?.outfitID)
    }

    func testTheClosetOpensOnlyWhenThePetIsClose() {
        var room = PlayRoom.starter()
        room.petWall = .closet
        room.pet = RoomSpot(x: 0.5, y: 0.3)
        XCTAssertTrue(RoomRules.canOpenCloset(room))
        room.petWall = .toys
        XCTAssertFalse(RoomRules.canOpenCloset(room))
    }
}
