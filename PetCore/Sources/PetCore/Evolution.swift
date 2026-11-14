import Foundation

/// How the baby was looked after before their adult form is chosen.
public struct CareHistory: Codable, Equatable, Sendable {
    public var properFeeds: Int
    public var overfeeds: Int
    public var plays: Int
    public var hungerEmptySeconds: TimeInterval
    public var happinessEmptySeconds: TimeInterval

    public init(
        properFeeds: Int = 0,
        overfeeds: Int = 0,
        plays: Int = 0,
        hungerEmptySeconds: TimeInterval = 0,
        happinessEmptySeconds: TimeInterval = 0
    ) {
        self.properFeeds = properFeeds
        self.overfeeds = overfeeds
        self.plays = plays
        self.hungerEmptySeconds = hungerEmptySeconds
        self.happinessEmptySeconds = happinessEmptySeconds
    }

    public var neglectSeconds: TimeInterval {
        hungerEmptySeconds + happinessEmptySeconds
    }

    public var wasTouched: Bool {
        properFeeds > 0 || overfeeds > 0 || plays > 0
    }
}

public enum AdultForm: String, Codable, Equatable, Sendable, CaseIterable {
    case star
    case cloud
    case spiky

    public var displayName: String {
        switch self {
        case .star: return "Star"
        case .cloud: return "Cloud"
        case .spiky: return "Spiky"
        }
    }
}

public struct EvolutionRules: Equatable, Sendable {
    /// Time spent with Fed or Happy at zero. At or above this, the adult is spiky.
    public var spikyNeglectSeconds: TimeInterval
    /// Treats piled on past "full" push the adult toward the spoiled cloud form.
    public var cloudOverfeedCount: Int
    /// This many more plays than steady meals, with at least this many plays, is also spoiled.
    public var cloudExtraPlays: Int

    public init(
        spikyNeglectSeconds: TimeInterval = 2 * 60 * 60,
        cloudOverfeedCount: Int = 3,
        cloudExtraPlays: Int = 3
    ) {
        self.spikyNeglectSeconds = spikyNeglectSeconds
        self.cloudOverfeedCount = cloudOverfeedCount
        self.cloudExtraPlays = cloudExtraPlays
    }

    public static let standard = EvolutionRules()
}

public enum Evolution {
    /// Neglect wins, then spoiling, then balanced care. No care at all is spiky, not star.
    public static func form(for care: CareHistory, rules: EvolutionRules = .standard) -> AdultForm {
        if care.neglectSeconds >= rules.spikyNeglectSeconds || !care.wasTouched {
            return .spiky
        }
        if care.overfeeds >= rules.cloudOverfeedCount {
            return .cloud
        }
        if care.plays >= rules.cloudExtraPlays, care.plays >= care.properFeeds + rules.cloudExtraPlays {
            return .cloud
        }
        return .star
    }
}
