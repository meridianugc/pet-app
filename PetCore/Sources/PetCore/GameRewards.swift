import Foundation

public enum MiniGame: String, Codable, Equatable, Sendable, CaseIterable {
    case starCatch
    case memoryMatch
    case hideAndSeek
    case planetMerge
    case starHopper
    case snackMatch

    public var title: String {
        switch self {
        case .starCatch: return "Star Catch"
        case .memoryMatch: return "Memory Match"
        case .hideAndSeek: return "Hide and Seek"
        case .planetMerge: return "Planet Merge"
        case .starHopper: return "Star Hopper"
        case .snackMatch: return "Snack Match"
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
    /// Star gems from a score. A long game can score high; the gem payout grows slowly and stops at 24.
    public static func gems(forPoints points: Int) -> Int {
        let safe = max(0, points)
        if safe == 0 { return 0 }
        let scaled = (Double(safe) * 1.5).squareRoot().rounded()
        return min(24, max(1, Int(scaled)))
    }

    /// Points already include combos. A finished game always cheers them up a little and tires them.
    public static func reward(points: Int) -> GameReward {
        let gems = gems(forPoints: points)
        let happiness = min(30, 8 + Double(gems))
        let xp = 8 + gems * 2
        return GameReward(happiness: happiness, energyCost: 12, coins: gems, xp: xp)
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
