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
    case starlet
    case nova
    case constellation
    case cloud
    case mist
    case nimbus
    case aurora
    case spiky
    case pebble
    case comet
    case meteor

    /// The first form of this care branch. Later forms grow from it.
    public var root: AdultForm {
        switch self {
        case .star, .starlet, .nova, .constellation: return .star
        case .cloud, .mist, .nimbus, .aurora: return .cloud
        case .spiky, .pebble, .comet, .meteor: return .spiky
        }
    }

    public var displayName: String {
        switch self {
        case .star: return "Star"
        case .starlet: return "Starlet"
        case .nova: return "Nova"
        case .constellation: return "Constellation"
        case .cloud: return "Cloud"
        case .mist: return "Mist"
        case .nimbus: return "Nimbus"
        case .aurora: return "Aurora"
        case .spiky: return "Spiky"
        case .pebble: return "Pebble"
        case .comet: return "Comet"
        case .meteor: return "Meteor"
        }
    }

    /// Painted-art file name. The app draws a stand-in until that image exists.
    public var assetName: String {
        switch self {
        case .star: return "alien_star"
        case .starlet: return "alien_starlet"
        case .nova: return "alien_nova"
        case .constellation: return "alien_constellation"
        case .cloud: return "alien_cloud"
        case .mist: return "alien_mist"
        case .nimbus: return "alien_nimbus"
        case .aurora: return "alien_aurora"
        case .spiky: return "alien_spiky"
        case .pebble: return "alien_pebble"
        case .comet: return "alien_comet"
        case .meteor: return "alien_meteor"
        }
    }

    /// The pet level at which this form can appear.
    public var unlockLevel: Int {
        switch self {
        case .spiky: return 2
        case .cloud: return 4
        case .star: return 6
        case .pebble: return 10
        case .mist: return 12
        case .starlet: return 14
        case .comet: return 20
        case .nimbus: return 22
        case .nova: return 24
        case .meteor: return 32
        case .aurora: return 34
        case .constellation: return 36
        }
    }
}

public enum Youth {
    public static let toddlerAsset = "alien_toddler"
    public static let teenAsset = "alien_teen"

    public static func title(stage: LifeStage, level: Int) -> String? {
        guard stage == .baby else { return nil }
        if level >= 8 { return "Teen" }
        if level >= 4 { return "Toddler" }
        return nil
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

    /// Same care rules, but a form above the pet's level becomes the highest form they have reached.
    public static func form(for care: CareHistory, level: Int, rules: EvolutionRules = .standard) -> AdultForm {
        let wanted = form(for: care, rules: rules)
        let starters: [AdultForm] = [.spiky, .cloud, .star]
        let root: AdultForm
        if level >= wanted.unlockLevel {
            root = wanted
        } else if let best = starters.filter({ level >= $0.unlockLevel }).max(by: { $0.unlockLevel < $1.unlockLevel }) {
            root = best
        } else {
            root = wanted
        }
        let grown = AdultForm.allCases.filter { $0.root == root.root && level >= $0.unlockLevel }
        return grown.max { $0.unlockLevel < $1.unlockLevel } ?? root
    }
}
