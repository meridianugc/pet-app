import XCTest
@testable import PetCore

final class ShipCourseTests: XCTestCase {
    func testTheShipDriftsForwardAndAHitReturnsToTheCheckpoint() {
        var run = ShipRun()
        run = ShipCourse.step(run, left: (0, 1), right: (0, 0), dt: 1)
        XCTAssertGreaterThan(run.y, 40)
        let rock = ShipCourse.obstacles(level: 1)[0]
        run.x = rock.0
        run.y = rock.1
        run.checkpoint = 1_600
        let hit = ShipCourse.step(run, left: (0, 0), right: (0, 0), dt: 0.01)
        XCTAssertEqual(hit.checkpoint, 1_600)
        XCTAssertEqual(hit.y, 1_600, accuracy: 30)
    }

    func testTheDoorOpensTheNextLevelAndACardRoundTrips() {
        var run = ShipRun(y: ShipCourse.length - 1)
        run = ShipCourse.step(run, left: (0, 1), right: (0, 1), dt: 1)
        XCTAssertEqual(run.level, 2)
        XCTAssertEqual(run.y, 0, accuracy: 1)
        let card = PetCard.text(name: "Mochi", form: "star", level: 4)
        XCTAssertEqual(PetCard.parse(card)?.name, "Mochi")
        XCTAssertEqual(PetCard.parse(card)?.level, 4)
        XCTAssertNil(PetCard.parse("hello"))
    }
}
