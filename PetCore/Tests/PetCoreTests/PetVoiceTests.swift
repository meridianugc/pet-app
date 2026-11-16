import XCTest
@testable import PetCore

final class PetVoiceTests: XCTestCase {
    func testTasteIsStableAndTouchLinesChange() {
        let taste = PetTaste.roll(seed: 2)
        XCTAssertEqual(PetTaste.roll(seed: 2), taste)
        XCTAssertEqual(PetVoice.onTouch(.tickle, sleeping: false).line, "That tickles!")
        XCTAssertFalse(PetVoice.onTouch(.poke, sleeping: false).pleased)
        XCTAssertTrue(PetVoice.onTouch(.poke, sleeping: true).line.contains("zzz"))
    }

    func testGreetingsRequestsAndDiaryStayInRange() {
        XCTAssertEqual(PetVoice.greet(minutesAway: 5), "Can we play?")
        XCTAssertEqual(PetVoice.greet(minutesAway: 40), "I missed you!")
        XCTAssertTrue(PetVoice.boast(game: "Snack Match", score: 12).contains("12"))
        let ask = PetVoice.request(forDay: 4)
        XCTAssertFalse(ask.text.isEmpty)
        XCTAssertTrue(ask.itemID.hasPrefix("food."))
        XCTAssertFalse(PetVoice.diaryLine(seed: 1).isEmpty)
    }
}
