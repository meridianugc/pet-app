import Foundation
@testable import PetCore

enum EngineFixture {
    static let start = Date(timeIntervalSince1970: 1_700_000_000)

    static func rules(
        egg: TimeInterval = 1_000,
        baby: TimeInterval = 2_000,
        child: TimeInterval = 3_000,
        teen: TimeInterval = 4_000,
        hunger: Double = 10,
        happiness: Double = 10,
        energy: Double = 10,
        sleepEnergy: Double = 20,
        sleepHunger: Double = 5,
        sleepHappiness: Double = 0,
        neglect: TimeInterval = 1_000
    ) -> PetRules {
        var rules = PetRules()
        rules.eggDuration = egg
        rules.babyDuration = baby
        rules.childDuration = child
        rules.teenDuration = teen
        rules.hungerDecayPerHour = hunger
        rules.happinessDecayPerHour = happiness
        rules.energyDecayPerHour = energy
        rules.sleepEnergyPerHour = sleepEnergy
        rules.sleepHungerPerHour = sleepHunger
        rules.sleepHappinessPerHour = sleepHappiness
        rules.neglectDuration = neglect
        return rules
    }

    static func baby(rules: PetRules, hunger: Double = 80, happiness: Double = 80, energy: Double = 80) -> Pet {
        var pet = Pet.freshEgg(
            name: "Mochi",
            at: start,
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        )
        pet = PetEngine(rules: rules).advance(pet, to: start.addingTimeInterval(rules.eggDuration))
        pet.hunger = hunger
        pet.happiness = happiness
        pet.energy = energy
        pet.criticalSince = nil
        pet.isSleeping = false
        return pet
    }
}
