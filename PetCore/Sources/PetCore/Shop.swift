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
    case outfit
    case background
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

    public var isDurable: Bool {
        switch kind {
        case .outfit, .background: return true
        case .food, .toy: return false
        }
    }
}

public struct ItemEffect: Equatable, Sendable {
    public var hunger: Double
    public var happiness: Double
    public var countsAsTreat: Bool
    public var countsAsHealthyMeal: Bool

    public init(hunger: Double, happiness: Double, countsAsTreat: Bool, countsAsHealthyMeal: Bool) {
        self.hunger = hunger
        self.happiness = happiness
        self.countsAsTreat = countsAsTreat
        self.countsAsHealthyMeal = countsAsHealthyMeal
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
        gamesFinished: Int = 0
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
    }
}

public enum Shop {
    public static let catalog: [Goods] = [
        Goods(id: "food.starBerry", name: "Star berry", price: 8, unlockLevel: 1, kind: .food(hunger: 28, happiness: 4, treat: false, healthyMeal: true)),
        Goods(id: "food.cloudPuff", name: "Cloud puff", price: 12, unlockLevel: 1, kind: .food(hunger: 16, happiness: 14, treat: true, healthyMeal: false)),
        Goods(id: "food.moonCookie", name: "Moon cookie", price: 20, unlockLevel: 3, kind: .food(hunger: 40, happiness: 8, treat: false, healthyMeal: true)),
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
