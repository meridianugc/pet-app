import Foundation

public enum MiniGame: String, Codable, Equatable, Sendable, CaseIterable {
    case starCatch
    case memoryMatch
    case hideAndSeek

    public var title: String {
        switch self {
        case .starCatch: return "Star Catch"
        case .memoryMatch: return "Memory Match"
        case .hideAndSeek: return "Hide and Seek"
        }
    }
}

public struct GameReward: Equatable, Sendable {
    public var happiness: Double
    public var energyCost: Double
    public var coins: Int
    public var xp: Int

    public init(happiness: Double, energyCost: Double, coins: Int, xp: Int) {
        self.happiness = happiness
        self.energyCost = energyCost
        self.coins = coins
        self.xp = xp
    }
}

public enum GameRewards {
    /// Points already include penalties. A finished game always cheers them up a little and tires them.
    public static func reward(points: Int) -> GameReward {
        let safe = max(0, points)
        let coins = min(30, safe)
        let happiness = min(28, 8 + Double(safe) * 2)
        let xp = 6 + safe
        return GameReward(happiness: happiness, energyCost: 14, coins: coins, xp: xp)
    }

    public static func starCatchPoints(stars: Int, snacks: Int, rocks: Int) -> Int {
        max(0, stars * 2 + snacks - rocks * 2)
    }

    public static func memoryPoints(pairs: Int, misses: Int) -> Int {
        max(0, pairs * 3 - misses)
    }

    public static func hideAndSeekPoints(finds: Int) -> Int {
        max(0, finds * 4)
    }
}
