import Foundation

public enum TraitTint: String, Codable, Equatable, Sendable {
    case starlight
    case mist
    case dusk
    case stardust

    public var phrase: String {
        switch self {
        case .starlight: return "a pinch of starlight"
        case .mist: return "a bit of cloud-mist"
        case .dusk: return "a spark of dusk"
        case .stardust: return "a speck of stardust"
        }
    }
}

/// One gift left in the next egg: a color and a single small stat bonus.
public struct InheritedTrait: Codable, Equatable, Sendable {
    public var tint: TraitTint
    public var hungerBonus: Double
    public var happinessBonus: Double
    public var energyBonus: Double
    public var fromName: String

    public init(
        tint: TraitTint,
        hungerBonus: Double = 0,
        happinessBonus: Double = 0,
        energyBonus: Double = 0,
        fromName: String
    ) {
        self.tint = tint
        self.hungerBonus = hungerBonus
        self.happinessBonus = happinessBonus
        self.energyBonus = energyBonus
        self.fromName = fromName
    }

    public static func gift(from pet: Pet) -> InheritedTrait {
        switch pet.stage == .adult ? pet.displayForm : nil {
        case .star:
            return InheritedTrait(tint: .starlight, happinessBonus: 6, fromName: pet.name)
        case .cloud:
            return InheritedTrait(tint: .mist, energyBonus: 6, fromName: pet.name)
        case .spiky:
            return InheritedTrait(tint: .dusk, hungerBonus: 6, fromName: pet.name)
        case nil:
            return InheritedTrait(tint: .stardust, happinessBonus: 4, fromName: pet.name)
        }
    }
}

public struct HomeLetter: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var form: AdultForm?
    public var age: String
    public var wentHomeAt: Date
    public var message: String
    public var trait: InheritedTrait

    public init(
        id: UUID = UUID(),
        name: String,
        form: AdultForm?,
        age: String,
        wentHomeAt: Date,
        message: String,
        trait: InheritedTrait
    ) {
        self.id = id
        self.name = name
        self.form = form
        self.age = age
        self.wentHomeAt = wentHomeAt
        self.message = message
        self.trait = trait
    }
}

public struct PetCollection: Codable, Equatable, Sendable {
    public var raisedForms: [AdultForm]
    public var sawEgg: Bool
    public var sawBaby: Bool
    public var letters: [HomeLetter]

    public init(
        raisedForms: [AdultForm] = [],
        sawEgg: Bool = false,
        sawBaby: Bool = false,
        letters: [HomeLetter] = []
    ) {
        self.raisedForms = raisedForms
        self.sawEgg = sawEgg
        self.sawBaby = sawBaby
        self.letters = letters
    }

    public static let empty = PetCollection()

    public func noting(_ pet: Pet) -> PetCollection {
        var copy = self
        switch pet.stage {
        case .egg:
            copy.sawEgg = true
        case .baby:
            copy.sawEgg = true
            copy.sawBaby = true
        case .adult:
            copy.sawEgg = true
            copy.sawBaby = true
            if let form = pet.displayForm, !copy.raisedForms.contains(form) {
                copy.raisedForms.append(form)
            }
        }
        return copy
    }
}

public struct Homecoming: Equatable, Sendable {
    public var next: Pet
    public var collection: PetCollection
    public var letter: HomeLetter
}

public enum PetLineage {
    public static func letter(for pet: Pet) -> HomeLetter {
        let trait = InheritedTrait.gift(from: pet)
        let when = pet.wentHomeAt ?? pet.lastSimulatedAt
        let age = PetAge.phrase(from: pet.bornAt ?? pet.createdAt, to: when)
        let form = pet.stage == .adult ? pet.displayForm : nil
        let grown = form.map { "I grew into a \($0.displayName.lowercased()) alien" } ?? "I was still a little hatchling"
        let because = pet.homeReason?.note ?? "The stars were calling."
        let message = """
        Dear friend,

        It's \(pet.name). \(grown), and I was with you for \(age). \(because) I'm flying home to my planet, and I left \(trait.tint.phrase) in the new egg.

        Love,
        \(pet.name)
        """
        return HomeLetter(
            name: pet.name,
            form: form,
            age: age,
            wentHomeAt: when,
            message: message,
            trait: trait
        )
    }

    public static func succeed(_ pet: Pet, collection: PetCollection) -> Homecoming {
        var collection = collection.noting(pet)
        let note = letter(for: pet)
        collection.letters.insert(note, at: 0)
        let when = pet.wentHomeAt ?? pet.lastSimulatedAt
        let next = Pet.freshEgg(name: "Mochi", at: when, trait: note.trait)
        return Homecoming(next: next, collection: collection, letter: note)
    }
}
