import Foundation

public enum ShopError: Equatable, Error, Sendable {
    case unknownItem
    case notEnoughCoins(have: Int, need: Int)
    case levelLocked(required: Int)
    case alreadyOwned
    case noneLeft
    case notWearable
}

public enum GoodsKind: Equatable, Sendable {
    case food(hunger: Double, happiness: Double, treat: Bool, healthyMeal: Bool)
    case toy(happiness: Double)
    case tonic(hunger: Double, happiness: Double, energy: Double)
    case charm(percent: Int, hours: Double)
    case outfit
    case background
}

public enum CareStat: String, Codable, Equatable, Sendable {
    case fed
    case happy
    case energy
    case gems
    case sleep
    case look
    case sky
}

public struct CareChip: Equatable, Sendable {
    public var stat: CareStat
    public var amount: Int

    public init(stat: CareStat, amount: Int) {
        self.stat = stat
        self.amount = amount
    }
}

public struct Goods: Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var price: Int
    public var unlockLevel: Int
    public var kind: GoodsKind

    public init(id: String, name: String, price: Int, unlockLevel: Int, kind: GoodsKind) {
        self.id = id
        self.name = name
        self.price = price
        self.unlockLevel = unlockLevel
        self.kind = kind
    }

    /// Food, drink, and toys are for the pet. A charm can be used while they nap.
    public var needsThePetAwake: Bool {
        switch kind {
        case .food, .toy, .tonic: return true
        case .charm, .outfit, .background: return false
        }
    }

    public var isDurable: Bool {
        switch kind {
        case .outfit, .background: return true
        case .food, .toy, .tonic, .charm: return false
        }
    }

    /// What the item does, as numbers the screen draws with icons.
    public var chips: [CareChip] {
        switch kind {
        case let .food(hunger, happiness, _, _):
            return Self.chips(fed: hunger, happy: happiness)
        case let .toy(happiness):
            return Self.chips(happy: happiness)
        case let .tonic(hunger, happiness, energy):
            return Self.chips(fed: hunger, happy: happiness, energy: energy)
        case let .charm(percent, _):
            return [CareChip(stat: .gems, amount: percent)]
        case .outfit:
            return [CareChip(stat: .look, amount: 1)]
        case .background:
            return [CareChip(stat: .sky, amount: 1)]
        }
    }

    private static func chips(fed: Double = 0, happy: Double = 0, energy: Double = 0) -> [CareChip] {
        var chips: [CareChip] = []
        if fed != 0 { chips.append(CareChip(stat: .fed, amount: Int(fed.rounded()))) }
        if happy != 0 { chips.append(CareChip(stat: .happy, amount: Int(happy.rounded()))) }
        if energy != 0 { chips.append(CareChip(stat: .energy, amount: Int(energy.rounded()))) }
        return chips
    }
}

public struct ItemEffect: Equatable, Sendable {
    public var hunger: Double
    public var happiness: Double
    public var energy: Double
    public var countsAsTreat: Bool
    public var countsAsHealthyMeal: Bool
    public var gemBonusPercent: Int
    public var gemBonusHours: Double

    public init(
        hunger: Double,
        happiness: Double,
        energy: Double = 0,
        countsAsTreat: Bool,
        countsAsHealthyMeal: Bool,
        gemBonusPercent: Int = 0,
        gemBonusHours: Double = 0
    ) {
        self.hunger = hunger
        self.happiness = happiness
        self.energy = energy
        self.countsAsTreat = countsAsTreat
        self.countsAsHealthyMeal = countsAsHealthyMeal
        self.gemBonusPercent = gemBonusPercent
        self.gemBonusHours = gemBonusHours
    }

    public var chips: [CareChip] {
        var chips: [CareChip] = []
        if hunger != 0 { chips.append(CareChip(stat: .fed, amount: Int(hunger.rounded()))) }
        if happiness != 0 { chips.append(CareChip(stat: .happy, amount: Int(happiness.rounded()))) }
        if energy != 0 { chips.append(CareChip(stat: .energy, amount: Int(energy.rounded()))) }
        if gemBonusPercent != 0 { chips.append(CareChip(stat: .gems, amount: gemBonusPercent)) }
        return chips
    }
}

public struct PlayerProgress: Codable, Equatable, Sendable {
    public var coins: Int
    public var xp: Int
    public var ownedIDs: [String]
    public var stock: [String: Int]
    public var outfitID: String?
    public var backgroundID: String?
    public var daily: DailyState
    public var streak: CareStreak
    public var achievements: [Achievement]
    public var mealsFed: Int
    public var gamesFinished: Int
    public var bestScores: [String: Int]
    public var gemBonusPercent: Int
    public var gemBonusUntil: Date?
    public var wardrobe: Wardrobe
    public var claimedDexSets: [String]
    public var powers: PowerPouch

    public init(
        coins: Int = 0,
        xp: Int = 0,
        ownedIDs: [String] = [],
        stock: [String: Int] = [:],
        outfitID: String? = nil,
        backgroundID: String? = nil,
        daily: DailyState = DailyState(),
        streak: CareStreak = CareStreak(),
        achievements: [Achievement] = [],
        mealsFed: Int = 0,
        gamesFinished: Int = 0,
        bestScores: [String: Int] = [:],
        gemBonusPercent: Int = 0,
        gemBonusUntil: Date? = nil,
        wardrobe: Wardrobe = .plain,
        claimedDexSets: [String] = [],
        powers: PowerPouch = PowerPouch()
    ) {
        self.coins = coins
        self.xp = xp
        self.ownedIDs = ownedIDs
        self.stock = stock
        self.outfitID = outfitID
        self.backgroundID = backgroundID
        self.daily = daily
        self.streak = streak
        self.achievements = achievements
        self.mealsFed = mealsFed
        self.gamesFinished = gamesFinished
        self.bestScores = bestScores
        self.gemBonusPercent = gemBonusPercent
        self.gemBonusUntil = gemBonusUntil
        self.wardrobe = wardrobe
        self.claimedDexSets = claimedDexSets
        self.powers = powers
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        coins = try c.decodeIfPresent(Int.self, forKey: .coins) ?? 0
        xp = try c.decodeIfPresent(Int.self, forKey: .xp) ?? 0
        ownedIDs = try c.decodeIfPresent([String].self, forKey: .ownedIDs) ?? []
        stock = try c.decodeIfPresent([String: Int].self, forKey: .stock) ?? [:]
        outfitID = try c.decodeIfPresent(String.self, forKey: .outfitID)
        backgroundID = try c.decodeIfPresent(String.self, forKey: .backgroundID)
        daily = try c.decodeIfPresent(DailyState.self, forKey: .daily) ?? DailyState()
        streak = try c.decodeIfPresent(CareStreak.self, forKey: .streak) ?? CareStreak()
        achievements = try c.decodeIfPresent([Achievement].self, forKey: .achievements) ?? []
        mealsFed = try c.decodeIfPresent(Int.self, forKey: .mealsFed) ?? 0
        gamesFinished = try c.decodeIfPresent(Int.self, forKey: .gamesFinished) ?? 0
        bestScores = try c.decodeIfPresent([String: Int].self, forKey: .bestScores) ?? [:]
        gemBonusPercent = try c.decodeIfPresent(Int.self, forKey: .gemBonusPercent) ?? 0
        gemBonusUntil = try c.decodeIfPresent(Date.self, forKey: .gemBonusUntil)
        wardrobe = try c.decodeIfPresent(Wardrobe.self, forKey: .wardrobe) ?? .plain
        claimedDexSets = try c.decodeIfPresent([String].self, forKey: .claimedDexSets) ?? []
        powers = try c.decodeIfPresent(PowerPouch.self, forKey: .powers) ?? PowerPouch()
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(coins, forKey: .coins)
        try c.encode(xp, forKey: .xp)
        try c.encode(ownedIDs, forKey: .ownedIDs)
        try c.encode(stock, forKey: .stock)
        try c.encodeIfPresent(outfitID, forKey: .outfitID)
        try c.encodeIfPresent(backgroundID, forKey: .backgroundID)
        try c.encode(daily, forKey: .daily)
        try c.encode(streak, forKey: .streak)
        try c.encode(achievements, forKey: .achievements)
        try c.encode(mealsFed, forKey: .mealsFed)
        try c.encode(gamesFinished, forKey: .gamesFinished)
        try c.encode(bestScores, forKey: .bestScores)
        try c.encode(gemBonusPercent, forKey: .gemBonusPercent)
        try c.encodeIfPresent(gemBonusUntil, forKey: .gemBonusUntil)
        try c.encode(wardrobe, forKey: .wardrobe)
        try c.encode(claimedDexSets, forKey: .claimedDexSets)
        try c.encode(powers, forKey: .powers)
    }

    private enum CodingKeys: String, CodingKey {
        case coins, xp, ownedIDs, stock, outfitID, backgroundID
        case daily, streak, achievements, mealsFed, gamesFinished, bestScores
        case gemBonusPercent, gemBonusUntil, wardrobe, claimedDexSets, powers
    }

    /// Extra gems from a lucky charm. Expired charms pay the base amount.
    public func gemPayout(base: Int, now: Date) -> Int {
        guard gemBonusPercent > 0, let gemBonusUntil, gemBonusUntil > now, base > 0 else { return base }
        return base + max(1, base * gemBonusPercent / 100)
    }

    /// Returns whether this score is a new record for that game.
    public mutating func noteBest(gameID: String, score: Int) -> Bool {
        let previous = bestScores[gameID] ?? 0
        guard score > previous else { return false }
        bestScores[gameID] = score
        return true
    }
}

public enum Shop {
    public static let catalog: [Goods] = [
        Goods(id: "food.starBerry", name: "Star berry", price: 8, unlockLevel: 1, kind: .food(hunger: 28, happiness: 4, treat: false, healthyMeal: true)),
        Goods(id: "food.cloudPuff", name: "Cloud puff", price: 12, unlockLevel: 1, kind: .food(hunger: 16, happiness: 14, treat: true, healthyMeal: false)),
        Goods(id: "food.moonCookie", name: "Moon cookie", price: 20, unlockLevel: 3, kind: .food(hunger: 40, happiness: 8, treat: false, healthyMeal: true)),
        Goods(id: "food.moonMilk", name: "Moon milk", price: 14, unlockLevel: 1, kind: .tonic(hunger: 10, happiness: 4, energy: 15)),
        Goods(id: "charm.lucky", name: "Lucky pebble", price: 18, unlockLevel: 2, kind: .charm(percent: 10, hours: 1)),
        Goods(id: "toy.comet", name: "Squeaky comet", price: 15, unlockLevel: 2, kind: .toy(happiness: 18)),
        Goods(id: "outfit.scarf", name: "Scarf", price: 25, unlockLevel: 1, kind: .outfit),
        Goods(id: "outfit.bow", name: "Bow", price: 30, unlockLevel: 2, kind: .outfit),
        Goods(id: "outfit.helmet", name: "Tiny helmet", price: 40, unlockLevel: 4, kind: .outfit),
        Goods(id: "room.starfield", name: "Starfield", price: 35, unlockLevel: 3, kind: .background),
        Goods(id: "room.nebula", name: "Cotton nebula", price: 35, unlockLevel: 3, kind: .background)
    ]

    public static func item(_ id: String) -> Goods? {
        catalog.first { $0.id == id }
    }

    public static func purchase(id: String, progress: PlayerProgress, level: Int) -> Result<PlayerProgress, ShopError> {
        guard let item = item(id) else { return .failure(.unknownItem) }
        if level < item.unlockLevel { return .failure(.levelLocked(required: item.unlockLevel)) }
        if item.isDurable, progress.ownedIDs.contains(id) { return .failure(.alreadyOwned) }
        if progress.coins < item.price { return .failure(.notEnoughCoins(have: progress.coins, need: item.price)) }
        var progress = progress
        progress.coins -= item.price
        if item.isDurable {
            progress.ownedIDs.append(id)
        } else {
            progress.stock[id, default: 0] += 1
        }
        return .success(progress)
    }

    public static func equip(_ id: String?, progress: PlayerProgress) -> Result<PlayerProgress, ShopError> {
        var progress = progress
        guard let id else {
            progress.outfitID = nil
            return .success(progress)
        }
        guard let item = item(id), case .outfit = item.kind else { return .failure(.notWearable) }
        guard progress.ownedIDs.contains(id) else { return .failure(.noneLeft) }
        progress.outfitID = id
        return .success(progress)
    }

    public static func equipBackground(_ id: String?, progress: PlayerProgress) -> Result<PlayerProgress, ShopError> {
        var progress = progress
        guard let id else {
            progress.backgroundID = nil
            return .success(progress)
        }
        guard let item = item(id), case .background = item.kind else { return .failure(.notWearable) }
        guard progress.ownedIDs.contains(id) else { return .failure(.noneLeft) }
        progress.backgroundID = id
        return .success(progress)
    }

    /// Takes one food or toy out of the pantry and says what it does to the pet.
    public static func consume(id: String, progress: PlayerProgress) -> Result<(PlayerProgress, ItemEffect), ShopError> {
        guard let item = item(id) else { return .failure(.unknownItem) }
        let count = progress.stock[id, default: 0]
        guard count > 0 else { return .failure(.noneLeft) }
        var progress = progress
        if count == 1 {
            progress.stock.removeValue(forKey: id)
        } else {
            progress.stock[id] = count - 1
        }
        switch item.kind {
        case let .food(hunger, happiness, treat, healthy):
            return .success((progress, ItemEffect(hunger: hunger, happiness: happiness, countsAsTreat: treat, countsAsHealthyMeal: healthy)))
        case let .toy(happiness):
            return .success((progress, ItemEffect(hunger: 0, happiness: happiness, countsAsTreat: false, countsAsHealthyMeal: false)))
        case let .tonic(hunger, happiness, energy):
            return .success((progress, ItemEffect(hunger: hunger, happiness: happiness, energy: energy, countsAsTreat: false, countsAsHealthyMeal: true)))
        case let .charm(percent, hours):
            return .success((progress, ItemEffect(hunger: 0, happiness: 0, countsAsTreat: false, countsAsHealthyMeal: false, gemBonusPercent: percent, gemBonusHours: hours)))
        case .outfit, .background:
            return .failure(.notWearable)
        }
    }
}

public enum PetCare {
    /// Applies a shop item. Treats during the baby stage count toward the spoiled cloud form.
    public static func apply(_ effect: ItemEffect, to pet: Pet, rules: PetRules = PetRules()) -> Pet {
        var pet = pet
        pet.hunger = min(rules.statMax, max(rules.statMin, pet.hunger + effect.hunger))
        pet.happiness = min(rules.statMax, max(rules.statMin, pet.happiness + effect.happiness))
        pet.energy = min(rules.statMax, max(rules.statMin, pet.energy + effect.energy))
        if pet.stage == .baby {
            if effect.countsAsTreat {
                pet.care.overfeeds += 1
            } else if effect.countsAsHealthyMeal {
                pet.care.properFeeds += 1
            }
        }
        return pet
    }
}
