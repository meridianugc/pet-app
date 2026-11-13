import XCTest
@testable import PetCore

final class NotificationPlannerTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func planner(rules: PetRules, resolution: TimeInterval = 1) -> NotificationPlanner {
        NotificationPlanner(engine: PetEngine(rules: rules), resolution: resolution)
    }

    private func livingPet(rules: PetRules, hunger: Double, happiness: Double, energy: Double, sleeping: Bool = false) -> Pet {
        var pet = Pet.freshEgg(name: "Pip", at: start.addingTimeInterval(-rules.eggDuration))
        pet = PetEngine(rules: rules).advance(pet, to: start)
        pet.hunger = hunger
        pet.happiness = happiness
        pet.energy = energy
        pet.isSleeping = sleeping
        pet.criticalSince = nil
        pet.lastSimulatedAt = start
        return pet
    }

    func testHatchNotificationUsesTheEggClock() {
        var rules = PetRules()
        rules.eggDuration = 1_000
        rules.planHorizon = 5_000
        let egg = Pet.freshEgg(name: "Pip", at: start)
        let plan = planner(rules: rules).plan(pet: egg, now: start, includeAlreadyLow: false)
        XCTAssertEqual(plan.map(\.id), [PlannedNotification.hatchID])
        XCTAssertEqual(plan[0].fireAt, start.addingTimeInterval(1_000))
        XCTAssertTrue(plan[0].title.contains("Pip"))
        XCTAssertTrue(plan[0].body.contains("egg"))
    }

    func testHungerWarningMatchesTheDecayCurve() {
        var rules = PetRules()
        rules.hungerDecayPerHour = 10
        rules.happinessDecayPerHour = 0
        rules.energyDecayPerHour = 0
        rules.hungerWarning = 30
        rules.planHorizon = 20 * 3600
        rules.neglectDuration = 48 * 3600
        let pet = livingPet(rules: rules, hunger: 100, happiness: 90, energy: 90)
        let plan = planner(rules: rules).plan(pet: pet, now: start, includeAlreadyLow: false)
        let hunger = plan.first { $0.id == PlannedNotification.hungerID }
        XCTAssertNotNil(hunger)
        let expected = start.addingTimeInterval(7 * 3600)
        XCTAssertEqual(hunger?.fireAt.timeIntervalSince(expected) ?? 999, 0, accuracy: 2)
        XCTAssertTrue(hunger?.title.contains("Pip") == true)
    }

    func testAlreadyLowReminderIsOptional() {
        var rules = PetRules()
        rules.hungerDecayPerHour = 0
        rules.happinessDecayPerHour = 0
        rules.energyDecayPerHour = 0
        rules.hungerWarning = 30
        rules.alreadyLowReminderDelay = 120
        rules.planHorizon = 3600
        rules.neglectDuration = 10_000
        let pet = livingPet(rules: rules, hunger: 10, happiness: 90, energy: 90)
        let quiet = planner(rules: rules).plan(pet: pet, now: start, includeAlreadyLow: false)
        XCTAssertNil(quiet.first { $0.id == PlannedNotification.hungerID })
        let loud = planner(rules: rules).plan(pet: pet, now: start, includeAlreadyLow: true)
        let hunger = loud.first { $0.id == PlannedNotification.hungerID }
        XCTAssertEqual(hunger?.fireAt, start.addingTimeInterval(120))
    }

    func testDeathWarningLeadsTheMomentOfDeath() {
        var rules = PetRules()
        rules.hungerDecayPerHour = 0
        rules.happinessDecayPerHour = 0
        rules.energyDecayPerHour = 0
        rules.neglectDuration = 4 * 3600
        rules.deathWarningLead = 45 * 60
        rules.planHorizon = 10 * 3600
        rules.hungerWarning = 0
        rules.happinessWarning = 0
        rules.energyWarning = 0
        var pet = livingPet(rules: rules, hunger: 0, happiness: 50, energy: 80)
        pet.criticalSince = start
        let plan = planner(rules: rules).plan(pet: pet, now: start, includeAlreadyLow: false)
        let warning = plan.first { $0.id == PlannedNotification.criticalID }
        let expected = start.addingTimeInterval(4 * 3600 - 45 * 60)
        XCTAssertEqual(warning?.fireAt.timeIntervalSince(expected) ?? 999, 0, accuracy: 2)
        XCTAssertTrue(warning?.body.contains("aren't doing well") == true)
    }

    func testDeadPetAndFarAwayEggScheduleNothing() {
        var rules = PetRules()
        rules.planHorizon = 100
        rules.eggDuration = 10_000
        let egg = Pet.freshEgg(name: "Pip", at: start)
        XCTAssertTrue(planner(rules: rules).plan(pet: egg, now: start, includeAlreadyLow: true).isEmpty)

        var dead = livingPet(rules: PetRules(), hunger: 10, happiness: 10, energy: 10)
        dead.diedAt = start
        dead.deathReason = .hunger
        XCTAssertTrue(planner(rules: PetRules()).plan(pet: dead, now: start, includeAlreadyLow: true).isEmpty)
    }

    func testSleepingPetDoesNotGetATiredWarning() {
        var rules = PetRules()
        rules.energyDecayPerHour = 0
        rules.sleepEnergyPerHour = 30
        rules.hungerDecayPerHour = 0
        rules.sleepHungerPerHour = 0
        rules.happinessDecayPerHour = 0
        rules.energyWarning = 25
        rules.planHorizon = 6 * 3600
        rules.neglectDuration = 48 * 3600
        let pet = livingPet(rules: rules, hunger: 80, happiness: 80, energy: 10, sleeping: true)
        let plan = planner(rules: rules).plan(pet: pet, now: start, includeAlreadyLow: true)
        XCTAssertNil(plan.first { $0.id == PlannedNotification.energyID })
    }
}
