import XCTest
@testable import PetCore

final class PetDecayTests: XCTestCase {
    func testHungerDecaysFromElapsedTimeAndClampsAtZero() {
        let rules = EngineFixture.rules(hunger: 10)
        let engine = PetEngine(rules: rules)
        let pet = EngineFixture.baby(rules: rules, hunger: 80)
        let twoHours = engine.advance(pet, to: pet.lastSimulatedAt.addingTimeInterval(2 * 3600))
        XCTAssertEqual(twoHours.hunger, 60, accuracy: 0.01)

        let drained = engine.advance(pet, to: pet.lastSimulatedAt.addingTimeInterval(20 * 3600))
        XCTAssertEqual(drained.hunger, 0, accuracy: 0.01)
        XCTAssertGreaterThanOrEqual(drained.hunger, 0)
    }

    func testOneJumpMatchesSeveralSmallerJumpsAcrossSleep() {
        var rules = EngineFixture.rules(hunger: 4, happiness: 0, energy: 50, sleepEnergy: 50, sleepHunger: 4, neglect: 100_000)
        rules.happinessDecayPerHour = 0
        let engine = PetEngine(rules: rules)
        let pet = EngineFixture.baby(rules: rules, hunger: 90, happiness: 70, energy: 100)
        let end = pet.lastSimulatedAt.addingTimeInterval(4 * 3600)

        let jumped = engine.advance(pet, to: end)
        var stepped = pet
        var cursor = pet.lastSimulatedAt
        while cursor < end {
            cursor = cursor.addingTimeInterval(3600)
            stepped = engine.advance(stepped, to: cursor)
        }

        XCTAssertEqual(jumped.stage, stepped.stage)
        XCTAssertEqual(jumped.isSleeping, stepped.isSleeping)
        XCTAssertEqual(jumped.hasGoneHome, stepped.hasGoneHome)
        XCTAssertEqual(jumped.hunger, stepped.hunger, accuracy: 0.01)
        XCTAssertEqual(jumped.happiness, stepped.happiness, accuracy: 0.01)
        XCTAssertEqual(jumped.energy, stepped.energy, accuracy: 0.01)
        XCTAssertEqual(jumped.passedOut, stepped.passedOut)
    }

    func testClockDoesNotRunBackward() {
        let engine = PetEngine(rules: EngineFixture.rules())
        let pet = EngineFixture.baby(rules: EngineFixture.rules())
        let earlier = engine.advance(pet, to: pet.lastSimulatedAt.addingTimeInterval(-500))
        XCTAssertEqual(earlier, pet)
        let same = engine.advance(pet, to: pet.lastSimulatedAt)
        XCTAssertEqual(same, pet)
    }

    func testManualClockIsWhatAdvanceSees() {
        var clock = ManualClock(now: EngineFixture.start)
        clock.advance(by: 90)
        let rules = EngineFixture.rules(hunger: 0, happiness: 0, energy: 0)
        let engine = PetEngine(rules: rules)
        var pet = EngineFixture.baby(rules: rules, hunger: 50, happiness: 50, energy: 50)
        pet.lastSimulatedAt = EngineFixture.start
        let moved = engine.advance(pet, clock: clock)
        XCTAssertEqual(moved.lastSimulatedAt, EngineFixture.start.addingTimeInterval(90))
        XCTAssertEqual(moved.hunger, 50, accuracy: 0.001)
    }

    func testFeedPlaysAndRefusesWhenItShould() {
        var rules = EngineFixture.rules(hunger: 10, happiness: 0, energy: 0)
        rules.feedHunger = 30
        rules.feedHappiness = 5
        rules.overfeedAt = 85
        rules.overfeedHappinessPenalty = 10
        rules.playHappiness = 20
        rules.playEnergyCost = 15
        rules.playHungerCost = 5
        rules.minimumEnergyToPlay = 12
        let engine = PetEngine(rules: rules)
        let pet = EngineFixture.baby(rules: rules, hunger: 50, happiness: 40, energy: 40)
        let later = pet.lastSimulatedAt.addingTimeInterval(3600)

        let fed = engine.perform(.feed, on: pet, at: later)
        XCTAssertTrue(fed.applied)
        XCTAssertEqual(fed.note, "Yum.")
        XCTAssertEqual(fed.pet.hunger, 70, accuracy: 0.01)
        XCTAssertEqual(fed.pet.happiness, 45, accuracy: 0.01)

        var stuffed = pet
        stuffed.hunger = 90
        let over = engine.perform(.feed, on: stuffed, at: stuffed.lastSimulatedAt)
        XCTAssertTrue(over.applied)
        XCTAssertEqual(over.note, "That was too much food.")
        XCTAssertEqual(over.pet.hunger, 100, accuracy: 0.01)
        XCTAssertEqual(over.pet.happiness, 30, accuracy: 0.01)

        let played = engine.perform(.play, on: pet, at: pet.lastSimulatedAt)
        XCTAssertTrue(played.applied)
        XCTAssertEqual(played.pet.happiness, 60, accuracy: 0.01)
        XCTAssertEqual(played.pet.energy, 25, accuracy: 0.01)
        XCTAssertEqual(played.pet.hunger, 45, accuracy: 0.01)

        var tired = pet
        tired.energy = 11
        let refused = engine.perform(.play, on: tired, at: tired.lastSimulatedAt)
        XCTAssertFalse(refused.applied)
        XCTAssertEqual(refused.note, "Too tired to play.")
        XCTAssertEqual(refused.pet.energy, 11, accuracy: 0.01)

        let egg = Pet.freshEgg(name: "Pip", at: EngineFixture.start)
        XCTAssertEqual(engine.perform(.feed, on: egg, at: EngineFixture.start).note, "Still an egg.")
        XCTAssertFalse(engine.perform(.play, on: egg, at: EngineFixture.start).applied)
    }

    func testSleepRestoresEnergySlowsHungerAndWakesWhenFull() {
        var rules = EngineFixture.rules(hunger: 10, happiness: 6, energy: 10, sleepEnergy: 30, sleepHunger: 4, sleepHappiness: 0)
        rules.statMax = 100
        let engine = PetEngine(rules: rules)
        let pet = EngineFixture.baby(rules: rules, hunger: 80, happiness: 50, energy: 40)
        let began = engine.perform(.beginSleep, on: pet, at: pet.lastSimulatedAt)
        XCTAssertTrue(began.applied)
        XCTAssertEqual(began.note, "Sweet dreams.")
        XCTAssertTrue(began.pet.isSleeping)
        XCTAssertFalse(began.pet.passedOut)

        let hour = engine.advance(began.pet, to: pet.lastSimulatedAt.addingTimeInterval(3600))
        XCTAssertTrue(hour.isSleeping)
        XCTAssertEqual(hour.energy, 70, accuracy: 0.01)
        XCTAssertEqual(hour.hunger, 76, accuracy: 0.01)
        XCTAssertEqual(hour.happiness, 50, accuracy: 0.01)

        let full = engine.advance(began.pet, to: pet.lastSimulatedAt.addingTimeInterval(2 * 3600))
        XCTAssertFalse(full.isSleeping)
        XCTAssertEqual(full.energy, 100, accuracy: 0.01)
        XCTAssertEqual(full.hunger, 72, accuracy: 0.01)

        let awake = engine.perform(.wake, on: hour, at: hour.lastSimulatedAt)
        XCTAssertTrue(awake.applied)
        XCTAssertEqual(awake.note, "Good morning.")
        XCTAssertFalse(awake.pet.isSleeping)

        let asleepFeed = engine.perform(.feed, on: hour, at: hour.lastSimulatedAt)
        XCTAssertFalse(asleepFeed.applied)
        XCTAssertEqual(asleepFeed.note, "They're asleep.")

        var wideAwake = pet
        wideAwake.energy = 100
        XCTAssertEqual(engine.perform(.beginSleep, on: wideAwake, at: wideAwake.lastSimulatedAt).note, "Too awake to sleep.")
    }

    func testPassingOutThenWakingFromALongGap() {
        let rules = EngineFixture.rules(hunger: 0, happiness: 0, energy: 50, sleepEnergy: 50, sleepHunger: 0, neglect: 100_000)
        let engine = PetEngine(rules: rules)
        let pet = EngineFixture.baby(rules: rules, hunger: 80, happiness: 80, energy: 100)
        let collapsed = engine.advance(pet, to: pet.lastSimulatedAt.addingTimeInterval(2 * 3600))
        XCTAssertTrue(collapsed.isSleeping)
        XCTAssertTrue(collapsed.passedOut)
        XCTAssertEqual(collapsed.energy, 0, accuracy: 0.05)

        let recovered = engine.advance(pet, to: pet.lastSimulatedAt.addingTimeInterval(4 * 3600))
        XCTAssertFalse(recovered.isSleeping)
        XCTAssertFalse(recovered.passedOut)
        XCTAssertEqual(recovered.energy, 100, accuracy: 0.05)
    }
}
