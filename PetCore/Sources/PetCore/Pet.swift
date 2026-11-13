import Foundation

public enum LifeStage: String, Codable, Equatable, CaseIterable {
    case egg
    case baby
    case child
    case teen
    case adult

    public var displayName: String {
        switch self {
        case .egg: return "Egg"
        case .baby: return "Baby"
        case .child: return "Child"
        case .teen: return "Teen"
        case .adult: return "Adult"
        }
    }

    public var next: LifeStage? {
        switch self {
        case .egg: return .baby
        case .baby: return .child
        case .child: return .teen
        case .teen: return .adult
        case .adult: return nil
        }
    }
}

public enum DeathReason: String, Codable, Equatable {
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

public struct Pet: Codable, Equatable, Identifiable {
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

    public var isDead: Bool { diedAt != nil }

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
        lastSimulatedAt: Date
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

public struct PetRecord: Codable, Equatable {
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
