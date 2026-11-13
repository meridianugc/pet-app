import XCTest
@testable import PetCore

final class PetMoodTests: XCTestCase {
    private func pet(stage: LifeStage = .baby, hunger: Double = 80, happiness: Double = 80, energy: Double = 80, sleeping: Bool = false, dead: Bool = false) -> Pet {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var pet = Pet.freshEgg(name: "Pip", at: now)
        pet.stage = stage
        pet.hunger = hunger
        pet.happiness = happiness
        pet.energy = energy
        pet.isSleeping = sleeping
        if dead {
            pet.diedAt = now
            pet.deathReason = .hunger
        }
        return pet
    }

    func testMoodPriority() {
        XCTAssertEqual(PetMood.resolve(pet(stage: .egg)), .egging)
        XCTAssertEqual(PetMood.resolve(pet(dead: true)), .gone)
        XCTAssertEqual(PetMood.resolve(pet(sleeping: true, dead: false)), .sleepy)
        XCTAssertEqual(PetMood.resolve(pet(hunger: 0, happiness: 80, energy: 80)), .critical)
        XCTAssertEqual(PetMood.resolve(pet(hunger: 20, happiness: 80, energy: 80)), .hungry)
        XCTAssertEqual(PetMood.resolve(pet(hunger: 80, happiness: 10, energy: 80)), .sad)
        XCTAssertEqual(PetMood.resolve(pet(hunger: 80, happiness: 80, energy: 10)), .tired)
        XCTAssertEqual(PetMood.resolve(pet(hunger: 90, happiness: 90, energy: 80)), .joyful)
        XCTAssertEqual(PetMood.resolve(pet(hunger: 50, happiness: 50, energy: 40)), .content)
        XCTAssertEqual(PetMood.critical.blurb, "Needs you now.")
    }

    func testSpokenSummaryMentionsTheNameAndTheNeed() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let egg = Pet.freshEgg(name: "Pip", at: now)
        XCTAssertTrue(PetCopy.summary(egg, now: now).contains("Pip"))
        XCTAssertTrue(PetCopy.summary(egg, now: now).contains("egg"))
        XCTAssertTrue(PetCopy.stageLine(egg, now: now).contains("Hatches"))

        var hungry = pet(hunger: 10, happiness: 80, energy: 80)
        hungry.bornAt = now.addingTimeInterval(-3600)
        XCTAssertTrue(PetCopy.statusLine(hungry).contains("hungry"))
        XCTAssertTrue(PetCopy.summary(hungry, now: now).contains("Fed 10 percent"))
    }

    func testAgePhrases() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertEqual(PetAge.phrase(from: start, to: start.addingTimeInterval(20)), "just a moment")
        XCTAssertEqual(PetAge.phrase(from: start, to: start.addingTimeInterval(60)), "1 minute")
        XCTAssertEqual(PetAge.phrase(from: start, to: start.addingTimeInterval(2 * 60)), "2 minutes")
        XCTAssertEqual(PetAge.phrase(from: start, to: start.addingTimeInterval(3 * 3600)), "3 hours")
        XCTAssertEqual(PetAge.phrase(from: start, to: start.addingTimeInterval(3 * 86400)), "3 days")
        XCTAssertEqual(PetAge.remaining(30), "less than a minute")
        XCTAssertEqual(PetAge.remaining(3600), "1 hour")
        XCTAssertEqual(PetAge.remaining(3600 + 5 * 60), "1 hour 5 minutes")
    }
}
