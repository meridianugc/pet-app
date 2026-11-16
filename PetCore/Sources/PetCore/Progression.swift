import Foundation

public struct DayStamp: Codable, Equatable, Hashable, Sendable {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public static func capture(_ date: Date, calendar: Calendar) -> DayStamp {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return DayStamp(year: parts.year ?? 1, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    public func date(in calendar: Calendar) -> Date? {
        var parts = DateComponents()
        parts.year = year
        parts.month = month
        parts.day = day
        parts.hour = 12
        return calendar.date(from: parts)
    }

    public func isDayAfter(_ previous: DayStamp, calendar: Calendar) -> Bool {
        guard let start = previous.date(in: calendar),
              let next = calendar.date(byAdding: .day, value: 1, to: start) else { return false }
        return DayStamp.capture(next, calendar: calendar) == self
    }
}

public enum DailyTask: String, Codable, Equatable, CaseIterable, Sendable {
    case playGames
    case healthyMeal
    case tuckIn

    public var title: String {
        switch self {
        case .playGames: return "Play 2 games"
        case .healthyMeal: return "Feed a healthy meal"
        case .tuckIn: return "Tuck in for sleep"
        }
    }

    public var reward: Int {
        switch self {
        case .playGames: return 12
        case .healthyMeal: return 10
        case .tuckIn: return 8
        }
    }
}

public struct DailyState: Codable, Equatable, Sendable {
    public var day: DayStamp?
    public var gamesPlayed: Int
    public var healthyMeals: Int
    public var tuckedIn: Bool
    public var claimed: [DailyTask]

    public init(
        day: DayStamp? = nil,
        gamesPlayed: Int = 0,
        healthyMeals: Int = 0,
        tuckedIn: Bool = false,
        claimed: [DailyTask] = []
    ) {
        self.day = day
        self.gamesPlayed = gamesPlayed
        self.healthyMeals = healthyMeals
        self.tuckedIn = tuckedIn
        self.claimed = claimed
    }

    public func isComplete(_ task: DailyTask) -> Bool {
        switch task {
        case .playGames: return gamesPlayed >= 2
        case .healthyMeal: return healthyMeals >= 1
        case .tuckIn: return tuckedIn
        }
    }
}

public enum DailyBoard {
    public static func refreshed(_ state: DailyState, on date: Date, calendar: Calendar) -> DailyState {
        let today = DayStamp.capture(date, calendar: calendar)
        guard state.day == today else {
            return DailyState(day: today)
        }
        return state
    }

    public static func recordGame(_ state: DailyState, on date: Date, calendar: Calendar) -> DailyState {
        var state = refreshed(state, on: date, calendar: calendar)
        state.gamesPlayed += 1
        return state
    }

    public static func recordHealthyMeal(_ state: DailyState, on date: Date, calendar: Calendar) -> DailyState {
        var state = refreshed(state, on: date, calendar: calendar)
        state.healthyMeals += 1
        return state
    }

    public static func recordSleep(_ state: DailyState, on date: Date, calendar: Calendar) -> DailyState {
        var state = refreshed(state, on: date, calendar: calendar)
        state.tuckedIn = true
        return state
    }

    public static func claim(_ task: DailyTask, state: DailyState, on date: Date, calendar: Calendar) -> (DailyState, Int)? {
        var state = refreshed(state, on: date, calendar: calendar)
        guard state.isComplete(task), !state.claimed.contains(task) else { return nil }
        state.claimed.append(task)
        return (state, task.reward)
    }
}

public struct CareStreak: Codable, Equatable, Sendable {
    public var count: Int
    public var lastGoodDay: DayStamp?

    public init(count: Int = 0, lastGoodDay: DayStamp? = nil) {
        self.count = count
        self.lastGoodDay = lastGoodDay
    }
}

public enum Streak {
    public static func mark(_ streak: CareStreak, on day: DayStamp, calendar: Calendar) -> CareStreak {
        if streak.lastGoodDay == day { return streak }
        if let last = streak.lastGoodDay, day.isDayAfter(last, calendar: calendar) {
            return CareStreak(count: streak.count + 1, lastGoodDay: day)
        }
        return CareStreak(count: 1, lastGoodDay: day)
    }
}

public enum Achievement: String, Codable, Equatable, CaseIterable, Sendable {
    case firstMeal
    case firstGame
    case starForm
    case cloudForm
    case spikyForm
    case levelThree
    case streakThree
    case coinPile
    case dresser

    public var title: String {
        switch self {
        case .firstMeal: return "First meal"
        case .firstGame: return "First game"
        case .starForm: return "Raised a star"
        case .cloudForm: return "Raised a cloud"
        case .spikyForm: return "Raised a spiky"
        case .levelThree: return "Level 3"
        case .streakThree: return "Three-day streak"
        case .coinPile: return "Coin pile"
        case .dresser: return "Dressed up"
        }
    }
}

public enum Achievements {
    public static func sync(_ progress: PlayerProgress, collection: PetCollection) -> PlayerProgress {
        var progress = progress
        var earned: [Achievement] = []
        if progress.mealsFed > 0 { earned.append(.firstMeal) }
        if progress.gamesFinished > 0 { earned.append(.firstGame) }
        if collection.raisedForms.contains(.star) { earned.append(.starForm) }
        if collection.raisedForms.contains(.cloud) { earned.append(.cloudForm) }
        if collection.raisedForms.contains(.spiky) { earned.append(.spikyForm) }
        if LevelTable.level(for: progress.xp) >= 3 { earned.append(.levelThree) }
        if progress.streak.count >= 3 { earned.append(.streakThree) }
        if progress.coins >= 40 { earned.append(.coinPile) }
        if progress.ownedIDs.contains(where: { Shop.item($0)?.kind == .outfit }) { earned.append(.dresser) }
        for item in earned where !progress.achievements.contains(item) {
            progress.achievements.append(item)
        }
        return progress
    }
}
