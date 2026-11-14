import Foundation

public enum LifeStage: String, Codable, Equatable, CaseIterable, Sendable {
    case egg
    case baby
    case adult

    public var displayName: String {
        switch self {
        case .egg: return "Egg"
        case .baby: return "Baby"
        case .adult: return "Adult"
        }
    }

    public var next: LifeStage? {
        switch self {
        case .egg: return .baby
        case .baby: return .adult
        case .adult: return nil
        }
    }
}

public enum HomeReason: String, Codable, Equatable, Sendable {
    case hunger
    case loneliness

    public var note: String {
        switch self {
        case .hunger:
            return "Meals got a little scarce."
        case .loneliness:
            return "It got a little too quiet."
        }
    }
}

public struct Pet: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var stage: LifeStage
    public var stageStartedAt: Date
    public var createdAt: Date
    public var bornAt: Date?
    public var hunger: Double
    public var happiness: Double
    public var energy: Double
    public var isSleeping: Bool
    public var sleepStartedAt: Date?
    /// True when energy hit zero and they fell asleep on their own.
    public var passedOut: Bool
    public var criticalSince: Date?
    public var wentHomeAt: Date?
    public var homeReason: HomeReason?
    public var lastSimulatedAt: Date
    /// Care counted while they are a baby. The adult form is chosen from this.
    public var care: CareHistory
    /// Set when a baby grows up. Nil for an egg, a baby, or an older save.
    public var adultForm: AdultForm?
    /// Gift from the previous alien, carried by the egg and the hatchling.
    public var trait: InheritedTrait?

    public var hasGoneHome: Bool { wentHomeAt != nil }

    /// What to draw once they have grown up. Older saves with no form use the star.
    public var displayForm: AdultForm? {
        guard stage == .adult else { return nil }
        return adultForm ?? .star
    }

    public init(
        id: UUID,
        name: String,
        stage: LifeStage,
        stageStartedAt: Date,
        createdAt: Date,
        bornAt: Date?,
        hunger: Double,
        happiness: Double,
        energy: Double,
        isSleeping: Bool,
        sleepStartedAt: Date?,
        passedOut: Bool,
        criticalSince: Date?,
        wentHomeAt: Date?,
        homeReason: HomeReason?,
        lastSimulatedAt: Date,
        care: CareHistory = CareHistory(),
        adultForm: AdultForm? = nil,
        trait: InheritedTrait? = nil
    ) {
        self.id = id
        self.name = name
        self.stage = stage
        self.stageStartedAt = stageStartedAt
        self.createdAt = createdAt
        self.bornAt = bornAt
        self.hunger = hunger
        self.happiness = happiness
        self.energy = energy
        self.isSleeping = isSleeping
        self.sleepStartedAt = sleepStartedAt
        self.passedOut = passedOut
        self.criticalSince = criticalSince
        self.wentHomeAt = wentHomeAt
        self.homeReason = homeReason
        self.lastSimulatedAt = lastSimulatedAt
        self.care = care
        self.adultForm = adultForm
        self.trait = trait
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        let stageRaw = try c.decode(String.self, forKey: .stage)
        switch stageRaw {
        case "child", "teen":
            stage = .baby
        default:
            stage = LifeStage(rawValue: stageRaw) ?? .egg
        }
        stageStartedAt = try c.decode(Date.self, forKey: .stageStartedAt)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        bornAt = try c.decodeIfPresent(Date.self, forKey: .bornAt)
        hunger = try c.decode(Double.self, forKey: .hunger)
        happiness = try c.decode(Double.self, forKey: .happiness)
        energy = try c.decode(Double.self, forKey: .energy)
        isSleeping = try c.decode(Bool.self, forKey: .isSleeping)
        sleepStartedAt = try c.decodeIfPresent(Date.self, forKey: .sleepStartedAt)
        passedOut = try c.decodeIfPresent(Bool.self, forKey: .passedOut) ?? false
        criticalSince = try c.decodeIfPresent(Date.self, forKey: .criticalSince)
        wentHomeAt = try c.decodeIfPresent(Date.self, forKey: .wentHomeAt)
            ?? c.decodeIfPresent(Date.self, forKey: .diedAt)
        homeReason = try c.decodeIfPresent(HomeReason.self, forKey: .homeReason)
            ?? c.decodeIfPresent(HomeReason.self, forKey: .deathReason)
        lastSimulatedAt = try c.decode(Date.self, forKey: .lastSimulatedAt)
        care = try c.decodeIfPresent(CareHistory.self, forKey: .care) ?? CareHistory()
        adultForm = try c.decodeIfPresent(AdultForm.self, forKey: .adultForm)
        trait = try c.decodeIfPresent(InheritedTrait.self, forKey: .trait)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(stage, forKey: .stage)
        try c.encode(stageStartedAt, forKey: .stageStartedAt)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encodeIfPresent(bornAt, forKey: .bornAt)
        try c.encode(hunger, forKey: .hunger)
        try c.encode(happiness, forKey: .happiness)
        try c.encode(energy, forKey: .energy)
        try c.encode(isSleeping, forKey: .isSleeping)
        try c.encodeIfPresent(sleepStartedAt, forKey: .sleepStartedAt)
        try c.encode(passedOut, forKey: .passedOut)
        try c.encodeIfPresent(criticalSince, forKey: .criticalSince)
        try c.encodeIfPresent(wentHomeAt, forKey: .wentHomeAt)
        try c.encodeIfPresent(homeReason, forKey: .homeReason)
        try c.encode(lastSimulatedAt, forKey: .lastSimulatedAt)
        try c.encode(care, forKey: .care)
        try c.encodeIfPresent(adultForm, forKey: .adultForm)
        try c.encodeIfPresent(trait, forKey: .trait)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, stage, stageStartedAt, createdAt, bornAt
        case hunger, happiness, energy
        case isSleeping, sleepStartedAt, passedOut, criticalSince
        case diedAt, deathReason, wentHomeAt, homeReason, lastSimulatedAt, care, adultForm, trait
    }

    public static func freshEgg(
        name: String,
        at now: Date,
        id: UUID = UUID(),
        trait: InheritedTrait? = nil
    ) -> Pet {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeName = trimmed.isEmpty ? "Mochi" : String(trimmed.prefix(24))
        return Pet(
            id: id,
            name: safeName,
            stage: .egg,
            stageStartedAt: now,
            createdAt: now,
            bornAt: nil,
            hunger: 0,
            happiness: 0,
            energy: 0,
            isSleeping: false,
            sleepStartedAt: nil,
            passedOut: false,
            criticalSince: nil,
            wentHomeAt: nil,
            homeReason: nil,
            lastSimulatedAt: now,
            trait: trait
        )
    }
}

public struct PetRecord: Codable, Equatable, Sendable {
    public static let currentSchema = 2

    public var schemaVersion: Int
    public var pet: Pet
    public var debugTimeOffset: TimeInterval
    public var notificationPromptDismissed: Bool
    public var collection: PetCollection
    public var farewell: HomeLetter?
    public var progress: PlayerProgress

    public init(
        pet: Pet,
        debugTimeOffset: TimeInterval = 0,
        notificationPromptDismissed: Bool = false,
        collection: PetCollection = .empty,
        farewell: HomeLetter? = nil,
        progress: PlayerProgress = PlayerProgress()
    ) {
        self.schemaVersion = Self.currentSchema
        self.pet = pet
        self.debugTimeOffset = debugTimeOffset
        self.notificationPromptDismissed = notificationPromptDismissed
        self.collection = collection
        self.farewell = farewell
        self.progress = progress
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let stored = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        schemaVersion = stored > Self.currentSchema ? stored : Self.currentSchema
        pet = try c.decode(Pet.self, forKey: .pet)
        debugTimeOffset = try c.decodeIfPresent(TimeInterval.self, forKey: .debugTimeOffset) ?? 0
        notificationPromptDismissed = try c.decodeIfPresent(Bool.self, forKey: .notificationPromptDismissed) ?? false
        collection = try c.decodeIfPresent(PetCollection.self, forKey: .collection) ?? .empty
        farewell = try c.decodeIfPresent(HomeLetter.self, forKey: .farewell)
        progress = try c.decodeIfPresent(PlayerProgress.self, forKey: .progress) ?? PlayerProgress()
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(schemaVersion, forKey: .schemaVersion)
        try c.encode(pet, forKey: .pet)
        try c.encode(debugTimeOffset, forKey: .debugTimeOffset)
        try c.encode(notificationPromptDismissed, forKey: .notificationPromptDismissed)
        try c.encode(collection, forKey: .collection)
        try c.encodeIfPresent(farewell, forKey: .farewell)
        try c.encode(progress, forKey: .progress)
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, pet, debugTimeOffset, notificationPromptDismissed, collection, farewell, progress
    }
}
