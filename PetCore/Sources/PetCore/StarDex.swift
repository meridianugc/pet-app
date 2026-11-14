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

    public init(id: String, title: String, hint: String, rarity: DexRarity, setName: String) {
        self.id = id
        self.title = title
        self.hint = hint
        self.rarity = rarity
        self.setName = setName
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
        DexEntry(id: "form.egg", title: "Star egg", hint: "Name an egg and wait with it.", rarity: .common, setName: "Forms"),
        DexEntry(id: "form.baby", title: "Baby", hint: "Let the egg hatch.", rarity: .common, setName: "Forms"),
        DexEntry(id: "form.star", title: "Star", hint: "Raise a baby with great care.", rarity: .rare, setName: "Forms"),
        DexEntry(id: "form.cloud", title: "Cloud", hint: "Spoil a baby with too many treats.", rarity: .rare, setName: "Forms"),
        DexEntry(id: "form.spiky", title: "Spiky", hint: "Leave a baby needing you for too long.", rarity: .rare, setName: "Forms"),
        DexEntry(id: "outfit.scarf", title: "Scarf", hint: "Buy the scarf in the shop.", rarity: .common, setName: "Outfits"),
        DexEntry(id: "outfit.bow", title: "Bow", hint: "Buy the bow in the shop.", rarity: .common, setName: "Outfits"),
        DexEntry(id: "outfit.helmet", title: "Tiny helmet", hint: "Buy the tiny helmet in the shop.", rarity: .rare, setName: "Outfits"),
        DexEntry(id: "look.shell.stars", title: "Star shell", hint: "Buy the star shell for an egg.", rarity: .common, setName: "Looks"),
        DexEntry(id: "look.antenna.heart", title: "Heart antennae", hint: "Finish a space trip, then buy them.", rarity: .legendary, setName: "Looks"),
        DexEntry(id: "sticker.letter", title: "Home letter", hint: "Keep a letter when an alien flies home.", rarity: .rare, setName: "Stickers"),
        DexEntry(id: "sticker.game", title: "First game", hint: "Finish any mini-game.", rarity: .common, setName: "Stickers"),
        DexEntry(id: "sticker.postcard", title: "Postcard", hint: "Send them on a space trip and welcome them home.", rarity: .rare, setName: "Stickers")
    ]

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
        case "look.shell.stars": return progress.wardrobe.owned.contains("shell.stars")
        case "look.antenna.heart": return progress.wardrobe.owned.contains("antenna.heart")
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
