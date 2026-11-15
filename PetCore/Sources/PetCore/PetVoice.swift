import Foundation

/// What this pet prefers. Rolled once and kept.
public struct PetTaste: Codable, Equatable, Sendable {
    public var food: String
    public var toy: String
    public var game: String
    public var foodID: String

    public init(food: String, toy: String, game: String, foodID: String) {
        self.food = food
        self.toy = toy
        self.game = game
        self.foodID = foodID
    }

    public static let menu: [PetTaste] = [
        PetTaste(food: "star berries", toy: "squeaky comet", game: "Snack Match", foodID: "food.starBerry"),
        PetTaste(food: "moon milk", toy: "moon ball", game: "Star Hopper", foodID: "food.moonMilk"),
        PetTaste(food: "moon cookies", toy: "donut", game: "Planet Merge", foodID: "food.moonCookie")
    ]

    public static func roll(seed: Int) -> PetTaste {
        menu[abs(seed) % menu.count]
    }
}

public enum PetTouch: String, Sendable {
    case pet
    case tickle
    case poke
    case drag
}

public enum PetVoice {
    public static func onTouch(_ touch: PetTouch, sleeping: Bool) -> (line: String, pleased: Bool) {
        if sleeping { return ("Mmm... zzz.", true) }
        switch touch {
        case .pet: return ("Hehe.", true)
        case .tickle: return ("That tickles!", true)
        case .poke: return ("Hey, gentle.", false)
        case .drag: return ("Wheee!", true)
        }
    }

    public static func greet(minutesAway: Int) -> String {
        minutesAway >= 30 ? "I missed you!" : "Can we play?"
    }

    public static func boast(game: String, score: Int) -> String {
        "You scored \(score) in \(game)!"
    }

    public static func request(forDay day: Int) -> (text: String, itemID: String) {
        let taste = PetTaste.roll(seed: day)
        return ("I want \(taste.food) today.", taste.foodID)
    }

    public static func diaryLine(seed: Int) -> String {
        let lines = [
            "I drew a star with too many points.",
            "I found a shiny pebble by the window.",
            "I made a little mess, then a smaller one.",
            "I waited and hummed."
        ]
        return lines[abs(seed) % lines.count]
    }
}
