import Foundation

/// Short lines shared by the app, the widget, and VoiceOver.
public enum PetCopy {
    public static func summary(_ pet: Pet, now: Date, engine: PetEngine = PetEngine()) -> String {
        if pet.isDead {
            let lived = PetAge.phrase(from: pet.bornAt ?? pet.createdAt, to: pet.diedAt ?? now)
            let reason = pet.deathReason?.epitaph ?? "They ran out of time."
            return "\(pet.name) has passed on after \(lived). \(reason)"
        }
        if pet.stage == .egg {
            let left = engine.timeRemainingInStage(pet, at: now) ?? 0
            return "\(pet.name), still an egg. Hatches in \(PetAge.remaining(left))."
        }
        let mood = PetMood.resolve(pet, rules: engine.rules)
        let age = PetAge.phrase(from: pet.bornAt ?? pet.createdAt, to: now)
        let fed = Int(pet.hunger.rounded())
        let happy = Int(pet.happiness.rounded())
        let energy = Int(pet.energy.rounded())
        return "\(pet.name), \(pet.stage.displayName.lowercased()), \(age) old. \(mood.blurb) Fed \(fed) percent, happiness \(happy) percent, energy \(energy) percent."
    }

    public static func stageLine(_ pet: Pet, now: Date, engine: PetEngine = PetEngine()) -> String {
        if pet.isDead { return "At rest" }
        if pet.stage == .egg {
            let left = engine.timeRemainingInStage(pet, at: now) ?? 0
            return "Hatches in \(PetAge.remaining(left))"
        }
        if pet.stage == .adult {
            let age = PetAge.phrase(from: pet.bornAt ?? pet.createdAt, to: now)
            return "Adult · \(age) old"
        }
        let left = engine.timeRemainingInStage(pet, at: now) ?? 0
        return "\(pet.stage.displayName) · grows up in \(PetAge.remaining(left))"
    }

    public static func statusLine(_ pet: Pet) -> String {
        if pet.isDead { return PetMood.gone.blurb }
        if pet.passedOut && pet.isSleeping {
            return "Fell asleep from being tired."
        }
        return PetMood.resolve(pet).blurb
    }
}
