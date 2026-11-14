import Foundation

public enum LookSlot: String, Codable, Equatable, CaseIterable, Sendable {
    case shell
    case eyes
    case antenna
    case marking

    public var spoken: String {
        switch self {
        case .shell: return "Shell"
        case .eyes: return "Eyes"
        case .antenna: return "Antennae"
        case .marking: return "Markings"
        }
    }
}

public struct LookOption: Equatable, Sendable, Identifiable {
    public var id: String
    public var slot: LookSlot
    public var price: Int
    public var level: Int
    public var needsAchievement: Achievement?
    public var needsTrips: Int
    public var stage: LifeStage?
    public var form: AdultForm?

    public init(
        id: String,
        slot: LookSlot,
        price: Int,
        level: Int,
        needsAchievement: Achievement? = nil,
        needsTrips: Int = 0,
        stage: LifeStage? = nil,
        form: AdultForm? = nil
    ) {
        self.id = id
        self.slot = slot
        self.price = price
        self.level = level
        self.needsAchievement = needsAchievement
        self.needsTrips = needsTrips
        self.stage = stage
        self.form = form
    }
}

public struct Wardrobe: Codable, Equatable, Sendable {
    public var owned: [String]
    public var shell: String
    public var eyes: String
    public var antenna: String
    public var marking: String
    public var tripsFinished: Int

    public init(
        owned: [String],
        shell: String,
        eyes: String,
        antenna: String,
        marking: String,
        tripsFinished: Int = 0
    ) {
        self.owned = owned
        self.shell = shell
        self.eyes = eyes
        self.antenna = antenna
        self.marking = marking
        self.tripsFinished = tripsFinished
    }

    public static let plain = Wardrobe(
        owned: ["shell.plain", "eyes.round", "antenna.ball", "marking.none"],
        shell: "shell.plain",
        eyes: "eyes.round",
        antenna: "antenna.ball",
        marking: "marking.none"
    )

    public func equipped(in slot: LookSlot) -> String {
        switch slot {
        case .shell: return shell
        case .eyes: return eyes
        case .antenna: return antenna
        case .marking: return marking
        }
    }
}

public enum LookError: Equatable, Error, Sendable {
    case unknown
    case lockedLevel(Int)
    case lockedAchievement
    case lockedTrips(Int)
    case notEnoughGems(have: Int, need: Int)
    case alreadyOwned
    case notOwned
    case wrongStage
}

public enum LookBook {
    public static let options: [LookOption] = [
        LookOption(id: "shell.plain", slot: .shell, price: 0, level: 1, stage: .egg),
        LookOption(id: "shell.stripes", slot: .shell, price: 12, level: 1, stage: .egg),
        LookOption(id: "shell.stars", slot: .shell, price: 20, level: 2, stage: .egg),
        LookOption(id: "eyes.round", slot: .eyes, price: 0, level: 1),
        LookOption(id: "eyes.star", slot: .eyes, price: 16, level: 2),
        LookOption(id: "eyes.soft", slot: .eyes, price: 10, level: 1, needsAchievement: .firstMeal),
        LookOption(id: "antenna.ball", slot: .antenna, price: 0, level: 1),
        LookOption(id: "antenna.star", slot: .antenna, price: 18, level: 3),
        LookOption(id: "antenna.heart", slot: .antenna, price: 22, level: 2, needsTrips: 1),
        LookOption(id: "marking.none", slot: .marking, price: 0, level: 1),
        LookOption(id: "marking.freckles", slot: .marking, price: 14, level: 2),
        LookOption(id: "marking.belly", slot: .marking, price: 24, level: 4, form: .star)
    ]

    public static func option(_ id: String) -> LookOption? {
        options.first { $0.id == id }
    }

    public static func fits(_ option: LookOption, stage: LifeStage, form: AdultForm?) -> Bool {
        if let required = option.stage, required != stage { return false }
        if let required = option.form, stage != .adult || form != required { return false }
        return true
    }

    public static func buy(
        id: String,
        wardrobe: Wardrobe,
        coins: Int,
        level: Int,
        achievements: [Achievement]
    ) -> Result<(Wardrobe, Int), LookError> {
        guard let option = option(id) else { return .failure(.unknown) }
        if wardrobe.owned.contains(id) { return .failure(.alreadyOwned) }
        if level < option.level { return .failure(.lockedLevel(option.level)) }
        if let badge = option.needsAchievement, !achievements.contains(badge) {
            return .failure(.lockedAchievement)
        }
        if wardrobe.tripsFinished < option.needsTrips {
            return .failure(.lockedTrips(option.needsTrips))
        }
        if coins < option.price {
            return .failure(.notEnoughGems(have: coins, need: option.price))
        }
        var wardrobe = wardrobe
        wardrobe.owned.append(id)
        return .success((wardrobe, coins - option.price))
    }

    public static func wear(
        id: String,
        wardrobe: Wardrobe,
        stage: LifeStage,
        form: AdultForm?
    ) -> Result<Wardrobe, LookError> {
        guard let option = option(id) else { return .failure(.unknown) }
        guard wardrobe.owned.contains(id) else { return .failure(.notOwned) }
        guard fits(option, stage: stage, form: form) else { return .failure(.wrongStage) }
        var wardrobe = wardrobe
        switch option.slot {
        case .shell: wardrobe.shell = id
        case .eyes: wardrobe.eyes = id
        case .antenna: wardrobe.antenna = id
        case .marking: wardrobe.marking = id
        }
        return .success(wardrobe)
    }
}
