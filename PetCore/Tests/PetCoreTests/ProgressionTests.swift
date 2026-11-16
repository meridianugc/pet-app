import XCTest
@testable import PetCore

final class ProgressionTests: XCTestCase {
    private func calendar(_ identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier) ?? TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func moment(year: Int, month: Int, day: Int, hour: Int, calendar: Calendar) -> Date {
        var parts = DateComponents()
        parts.year = year
        parts.month = month
        parts.day = day
        parts.hour = hour
        parts.minute = 30
        return calendar.date(from: parts)!
    }

    func testLocalMidnightResetsTasksAndAnotherZoneDoesNot() {
        let newYork = calendar("America/New_York")
        let late = moment(year: 2026, month: 11, day: 13, hour: 23, calendar: newYork)
        let next = moment(year: 2026, month: 11, day: 14, hour: 0, calendar: newYork)
        var tasks = DailyBoard.recordGame(DailyState(), on: late, calendar: newYork)
        tasks = DailyBoard.recordGame(tasks, on: late, calendar: newYork)
        XCTAssertEqual(tasks.gamesPlayed, 2)
        let sameNight = DailyBoard.refreshed(tasks, on: late.addingTimeInterval(60), calendar: newYork)
        XCTAssertEqual(sameNight.gamesPlayed, 2)
        let morning = DailyBoard.refreshed(tasks, on: next, calendar: newYork)
        XCTAssertEqual(morning.gamesPlayed, 0)
        XCTAssertNotEqual(morning.day, tasks.day)

        let utc = calendar("UTC")
        let stillPreviousEveningInNewYork = late
        let utcDay = DayStamp.capture(stillPreviousEveningInNewYork, calendar: utc)
        let nyDay = DayStamp.capture(stillPreviousEveningInNewYork, calendar: newYork)
        XCTAssertNotEqual(utcDay, nyDay)
    }

    func testClaimPaysOnceAfterTheTaskIsDone() {
        let calendar = calendar("UTC")
        let date = moment(year: 2026, month: 3, day: 2, hour: 9, calendar: calendar)
        var tasks = DailyBoard.recordHealthyMeal(DailyState(), on: date, calendar: calendar)
        XCTAssertNil(DailyBoard.claim(.playGames, state: tasks, on: date, calendar: calendar))
        let first = DailyBoard.claim(.healthyMeal, state: tasks, on: date, calendar: calendar)
        XCTAssertEqual(first?.1, 10)
        tasks = first?.0 ?? tasks
        XCTAssertNil(DailyBoard.claim(.healthyMeal, state: tasks, on: date, calendar: calendar))
    }

    func testStreakGrowsAcrossDaysAndBreaksAfterAGap() {
        let calendar = calendar("UTC")
        let day1 = DayStamp.capture(moment(year: 2026, month: 5, day: 1, hour: 8, calendar: calendar), calendar: calendar)
        let day2 = DayStamp.capture(moment(year: 2026, month: 5, day: 2, hour: 8, calendar: calendar), calendar: calendar)
        let day4 = DayStamp.capture(moment(year: 2026, month: 5, day: 4, hour: 8, calendar: calendar), calendar: calendar)
        var streak = Streak.mark(CareStreak(), on: day1, calendar: calendar)
        XCTAssertEqual(streak.count, 1)
        streak = Streak.mark(streak, on: day1, calendar: calendar)
        XCTAssertEqual(streak.count, 1)
        streak = Streak.mark(streak, on: day2, calendar: calendar)
        XCTAssertEqual(streak.count, 2)
        streak = Streak.mark(streak, on: day4, calendar: calendar)
        XCTAssertEqual(streak.count, 1)
    }

    func testAchievementsNoticeFormsLevelsAndAStreak() {
        var progress = PlayerProgress(coins: 80, xp: 100, mealsFed: 1, gamesFinished: 1)
        progress.streak = CareStreak(count: 3, lastGoodDay: nil)
        progress = tryResult(Shop.purchase(id: "outfit.scarf", progress: progress, level: 3))
        var collection = PetCollection()
        collection.raisedForms = [.star, .spiky]
        progress = Achievements.sync(progress, collection: collection)
        XCTAssertTrue(progress.achievements.contains(.firstMeal))
        XCTAssertTrue(progress.achievements.contains(.firstGame))
        XCTAssertTrue(progress.achievements.contains(.starForm))
        XCTAssertTrue(progress.achievements.contains(.spikyForm))
        XCTAssertFalse(progress.achievements.contains(.cloudForm))
        XCTAssertTrue(progress.achievements.contains(.levelThree))
        XCTAssertTrue(progress.achievements.contains(.streakThree))
        XCTAssertTrue(progress.achievements.contains(.coinPile))
        XCTAssertTrue(progress.achievements.contains(.dresser))
        let again = Achievements.sync(progress, collection: collection)
        XCTAssertEqual(again.achievements.count, progress.achievements.count)
    }

    private func tryResult(_ result: Result<PlayerProgress, ShopError>) -> PlayerProgress {
        guard case let .success(value) = result else {
            XCTFail("expected success")
            fatalError("test helper")
        }
        return value
    }
}
