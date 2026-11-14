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

public enum DeathReason: String, Codable, Equatable, Sendable {
    case hunger
    case loneliness

    public var epitaph: String {
        switch self {
        case .hunger:
            return "They got too hungry for too long."
        case .loneliness:
            return "They were lonely for too long."
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
    public var diedAt: Date?
    public var deathReason: DeathReason?
    public var lastSimulatedAt: Date
    /// Care counted while they are a baby. The adult form is chosen from this.
    public var care: CareHistory
    /// Set when a baby grows up. Nil for an egg, a baby, or an older save.
    public var adultForm: AdultForm?

    public var isDead: Bool { diedAt != nil }

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
        diedAt: Date?,
        deathReason: DeathReason?,
        lastSimulatedAt: Date,
        care: CareHistory = CareHistory(),
        adultForm: AdultForm? = nil
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
        self.diedAt = diedAt
        self.deathReason = deathReason
        self.lastSimulatedAt = lastSimulatedAt
        self.care = care
        self.adultForm = adultForm
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
        diedAt = try c.decodeIfPresent(Date.self, forKey: .diedAt)
        deathReason = try c.decodeIfPresent(DeathReason.self, forKey: .deathReason)
        lastSimulatedAt = try c.decode(Date.self, forKey: .lastSimulatedAt)
        care = try c.decodeIfPresent(CareHistory.self, forKey: .care) ?? CareHistory()
        adultForm = try c.decodeIfPresent(AdultForm.self, forKey: .adultForm)
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
        try c.encodeIfPresent(diedAt, forKey: .diedAt)
        try c.encodeIfPresent(deathReason, forKey: .deathReason)
        try c.encode(lastSimulatedAt, forKey: .lastSimulatedAt)
        try c.encode(care, forKey: .care)
        try c.encodeIfPresent(adultForm, forKey: .adultForm)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, stage, stageStartedAt, createdAt, bornAt
        case hunger, happiness, energy
        case isSleeping, sleepStartedAt, passedOut, criticalSince
        case diedAt, deathReason, lastSimulatedAt, care, adultForm
    }

    public static func freshEgg(name: String, at now: Date, id: UUID = UUID()) -> Pet {
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
            diedAt: nil,
            deathReason: nil,
            lastSimulatedAt: now
        )
    }
}

public struct PetRecord: Codable, Equatable, Sendable {
    public static let currentSchema = 1

    public var schemaVersion: Int
    public var pet: Pet
    public var debugTimeOffset: TimeInterval
    public var notificationPromptDismissed: Bool

    public init(
        pet: Pet,
        debugTimeOffset: TimeInterval = 0,
        notificationPromptDismissed: Bool = false
    ) {
        self.schemaVersion = Self.currentSchema
        self.pet = pet
        self.debugTimeOffset = debugTimeOffset
        self.notificationPromptDismissed = notificationPromptDismissed
    }
}
