import Foundation

public enum PetMood: String, Codable, Equatable, Sendable {
    case egging
    case joyful
    case content
    case hungry
    case sad
    case tired
    case sleepy
    case critical
    case gone

    public var blurb: String {
        switch self {
        case .egging: return "Warm and quiet."
        case .joyful: return "Feeling great."
        case .content: return "Doing fine."
        case .hungry: return "Getting hungry."
        case .sad: return "Would like some play."
        case .tired: return "Getting sleepy."
        case .sleepy: return "Sleeping."
        case .critical: return "Needs you now."
        case .gone: return "At rest."
        }
    }

    /// Higher is better on every stat. Mood uses the worst need first.
    public static func resolve(_ pet: Pet, rules: PetRules = PetRules()) -> PetMood {
        if pet.isDead { return .gone }
        if pet.stage == .egg { return .egging }
        if pet.isSleeping { return .sleepy }
        let hungerEmpty = pet.hunger <= rules.statMin + 0.001
        let happinessEmpty = pet.happiness <= rules.statMin + 0.001
        if hungerEmpty || happinessEmpty { return .critical }
        if pet.hunger < rules.hungerWarning { return .hungry }
        if pet.happiness < rules.happinessWarning { return .sad }
        if pet.energy < rules.energyWarning { return .tired }
        if pet.hunger >= 70, pet.happiness >= 70, pet.energy >= 50 { return .joyful }
        return .content
    }
}
