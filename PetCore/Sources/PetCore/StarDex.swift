import Foundation

public enum DexRarity: String, Codable, Equatable, Sendable {
    case common
    case rare
    case legendary
}

public struct DexEntry: Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var hint: String
    public var rarity: DexRarity
    public var setName: String
    public var unlockLevel: Int

    public init(id: String, title: String, hint: String, rarity: DexRarity, setName: String, unlockLevel: Int = 1) {
        self.id = id
        self.title = title
        self.hint = hint
        self.rarity = rarity
        self.setName = setName
        self.unlockLevel = unlockLevel
    }
}

public struct DexStatus: Equatable, Sendable {
    public var found: Int
    public var total: Int
    public var fraction: Double
    public var completedSets: [String]

    public init(found: Int, total: Int, fraction: Double, completedSets: [String]) {
        self.found = found
        self.total = total
        self.fraction = fraction
        self.completedSets = completedSets
    }
}

public enum StarDex {
    public static let entries: [DexEntry] = [
        DexEntry(id: "form.egg", title: "Star egg", hint: "Name an egg and wait with it.", rarity: .common, setName: "Forms", unlockLevel: 1),
        DexEntry(id: "form.baby", title: "Baby", hint: "Let the egg hatch.", rarity: .common, setName: "Forms", unlockLevel: 1),
        DexEntry(id: "form.spiky", title: "Spiky", hint: "Leave a baby needing you for too long.", rarity: .rare, setName: "Forms", unlockLevel: 2),
        DexEntry(id: "form.cloud", title: "Cloud", hint: "Spoil a baby with too many treats.", rarity: .rare, setName: "Forms", unlockLevel: 4),
        DexEntry(id: "form.star", title: "Star", hint: "Raise a baby with great care.", rarity: .rare, setName: "Forms", unlockLevel: 6),
        DexEntry(id: "outfit.scarf", title: "Scarf", hint: "Buy the scarf in the shop.", rarity: .common, setName: "Outfits", unlockLevel: 1),
        DexEntry(id: "outfit.bow", title: "Bow", hint: "Buy the bow in the shop.", rarity: .common, setName: "Outfits", unlockLevel: 2),
        DexEntry(id: "outfit.helmet", title: "Tiny helmet", hint: "Buy the tiny helmet in the shop.", rarity: .rare, setName: "Outfits", unlockLevel: 4),
        DexEntry(id: "sticker.letter", title: "Home letter", hint: "Keep a letter when an alien flies home.", rarity: .rare, setName: "Stickers"),
        DexEntry(id: "sticker.game", title: "First game", hint: "Finish any mini-game.", rarity: .common, setName: "Stickers"),
        DexEntry(id: "sticker.postcard", title: "Postcard", hint: "Send them on a space trip and welcome them home.", rarity: .rare, setName: "Stickers", unlockLevel: 3)
    ] + LookBook.options.map { option in
        DexEntry(
            id: "look.\(option.id)",
            title: option.id,
            hint: "Open it in the dressing room.",
            rarity: option.level >= 4 || option.needsTrips > 0 ? .legendary : (option.price > 0 ? .rare : .common),
            setName: "Looks",
            unlockLevel: max(option.level, option.needsTrips > 0 ? 3 : 1)
        )
    }

    public static func isFound(
        id: String,
        collection: PetCollection,
        progress: PlayerProgress,
        world: AwayWorld = .fresh(at: .distantPast)
    ) -> Bool {
        switch id {
        case "form.egg": return collection.sawEgg
        case "form.baby": return collection.sawBaby
        case "form.star": return collection.raisedForms.contains(.star)
        case "form.cloud": return collection.raisedForms.contains(.cloud)
        case "form.spiky": return collection.raisedForms.contains(.spiky)
        case "outfit.scarf", "outfit.bow", "outfit.helmet":
            return progress.ownedIDs.contains(id)
        case let id where id.hasPrefix("look."):
            return progress.wardrobe.owned.contains(String(id.dropFirst(5)))
        case "sticker.letter": return !collection.letters.isEmpty
        case "sticker.game": return progress.gamesFinished > 0
        case "sticker.postcard": return !world.postcards.isEmpty
        default: return false
        }
    }

    public static func status(
        collection: PetCollection,
        progress: PlayerProgress,
        world: AwayWorld = .fresh(at: .distantPast)
    ) -> DexStatus {
        let found = entries.filter { isFound(id: $0.id, collection: collection, progress: progress, world: world) }.count
        let total = entries.count
        let sets = Set(entries.map(\.setName)).filter { set in
            entries.filter { $0.setName == set }.allSatisfy {
                isFound(id: $0.id, collection: collection, progress: progress, world: world)
            }
        }
        return DexStatus(
            found: found,
            total: total,
            fraction: total == 0 ? 0 : Double(found) / Double(total),
            completedSets: sets.sorted()
        )
    }

    public static func reward(for setName: String) -> Int {
        switch setName {
        case "Forms": return 30
        case "Outfits": return 20
        case "Looks": return 16
        case "Stickers": return 12
        default: return 0
        }
    }

    /// Pays a set once. Returns nil when it is incomplete or already claimed.
    public static func claim(setName: String, progress: PlayerProgress, collection: PetCollection) -> (PlayerProgress, Int)? {
        let state = status(collection: collection, progress: progress)
        guard state.completedSets.contains(setName), !progress.claimedDexSets.contains(setName) else { return nil }
        let gems = reward(for: setName)
        guard gems > 0 else { return nil }
        var progress = progress
        progress.coins += gems
        progress.claimedDexSets.append(setName)
        return (progress, gems)
    }
}
