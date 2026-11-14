import Foundation

public enum LevelTable {
    /// Level 1 at 0 XP. Each next level costs 20 XP more than the one before it, starting at 40.
    public static func level(for xp: Int) -> Int {
        var level = 1
        var remaining = max(0, xp)
        var step = 40
        while remaining >= step, level < 20 {
            remaining -= step
            level += 1
            step += 20
        }
        return level
    }

    public static func xpToReach(_ level: Int) -> Int {
        guard level > 1 else { return 0 }
        var total = 0
        var step = 40
        for _ in 2...level {
            total += step
            step += 20
        }
        return total
    }
}

public enum EvolutionBonus {
    public static let coins = 15
    public static let xp = 25

    public static func applies(before: Pet, after: Pet) -> Bool {
        before.stage != .adult && after.stage == .adult && after.adultForm != nil
    }
}
