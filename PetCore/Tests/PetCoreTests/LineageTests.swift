import XCTest
@testable import PetCore

final class LineageTests: XCTestCase {
    private func grown(_ form: AdultForm?, stage: LifeStage = .adult) -> Pet {
        var pet = Pet.freshEgg(name: "Pip", at: Date(timeIntervalSince1970: 1_700_000_000))
        pet.stage = stage
        pet.bornAt = pet.createdAt
        pet.adultForm = form
        pet.wentHomeAt = pet.createdAt.addingTimeInterval(3 * 60 * 60)
        pet.homeReason = .hunger
        pet.lastSimulatedAt = pet.wentHomeAt ?? pet.createdAt
        return pet
    }

    func testEachFormLeavesOneTrait() {
        let star = InheritedTrait.gift(from: grown(.star))
        XCTAssertEqual(star.tint, .starlight)
        XCTAssertEqual(star.happinessBonus, 6)
        XCTAssertEqual(star.hungerBonus, 0)
        XCTAssertEqual(star.energyBonus, 0)

        let cloud = InheritedTrait.gift(from: grown(.cloud))
        XCTAssertEqual(cloud.tint, .mist)
        XCTAssertEqual(cloud.energyBonus, 6)

        let spiky = InheritedTrait.gift(from: grown(.spiky))
        XCTAssertEqual(spiky.tint, .dusk)
        XCTAssertEqual(spiky.hungerBonus, 6)

        let baby = InheritedTrait.gift(from: grown(nil, stage: .baby))
        XCTAssertEqual(baby.tint, .stardust)
        XCTAssertEqual(baby.happinessBonus, 4)
    }

    func testLetterMentionsNameAgeAndForm() {
        let note = PetLineage.letter(for: grown(.cloud))
        XCTAssertTrue(note.message.contains("Pip"))
        XCTAssertTrue(note.message.contains("cloud"))
        XCTAssertTrue(note.message.contains(note.age))
        XCTAssertEqual(note.form, .cloud)
        XCTAssertTrue(note.message.contains("cloud-mist"))
    }

    func testGoingHomeStoresTheLetterAndHatchesAnEggWithTheTrait() {
        let pet = grown(.star)
        var collection = PetCollection()
        collection = collection.noting(pet)
        XCTAssertEqual(collection.raisedForms, [.star])

        let trip = PetLineage.succeed(pet, collection: collection)
        XCTAssertEqual(trip.next.stage, .egg)
        XCTAssertEqual(trip.next.trait?.tint, .starlight)
        XCTAssertEqual(trip.collection.letters.count, 1)
        XCTAssertEqual(trip.collection.letters[0].name, "Pip")
        XCTAssertEqual(trip.collection.raisedForms, [.star])

        let again = trip.collection.noting(pet)
        XCTAssertEqual(again.raisedForms, [.star])
    }

    func testHatchAppliesTheInheritedBonus() {
        let rules = EngineFixture.rules(egg: 10, hunger: 0, happiness: 0, energy: 0)
        let engine = PetEngine(rules: rules)
        var egg = Pet.freshEgg(
            name: "Nova",
            at: EngineFixture.start,
            trait: InheritedTrait(tint: .starlight, happinessBonus: 6, fromName: "Pip")
        )
        egg = engine.advance(egg, to: EngineFixture.start.addingTimeInterval(10))
        XCTAssertEqual(egg.stage, .baby)
        XCTAssertEqual(egg.happiness, rules.hatchHappiness + 6, accuracy: 0.01)
        XCTAssertEqual(egg.hunger, rules.hatchHunger, accuracy: 0.01)
        XCTAssertEqual(egg.trait?.fromName, "Pip")
    }
}
