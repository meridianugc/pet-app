import XCTest
@testable import PetCore

final class PetGrowthTests: XCTestCase {
    func testEggHatchesOnTimeAndNotBefore() {
        let rules = EngineFixture.rules()
        let engine = PetEngine(rules: rules)
        let egg = Pet.freshEgg(name: "Pip", at: EngineFixture.start)
        let early = engine.advance(egg, to: EngineFixture.start.addingTimeInterval(rules.eggDuration - 1))
        XCTAssertEqual(early.stage, .egg)
        XCTAssertNil(early.bornAt)
        XCTAssertEqual(early.hunger, 0, accuracy: 0.001)

        let hatched = engine.advance(egg, to: EngineFixture.start.addingTimeInterval(rules.eggDuration))
        XCTAssertEqual(hatched.stage, .baby)
        XCTAssertEqual(hatched.bornAt, EngineFixture.start.addingTimeInterval(rules.eggDuration))
        XCTAssertEqual(hatched.hunger, rules.hatchHunger, accuracy: 0.001)
        XCTAssertEqual(hatched.happiness, rules.hatchHappiness, accuracy: 0.001)
        XCTAssertEqual(hatched.energy, rules.hatchEnergy, accuracy: 0.001)
        XCTAssertNil(hatched.criticalSince)
        XCTAssertFalse(hatched.isDead)
    }

    func testEggDoesNotDieWhileWaiting() {
        var rules = EngineFixture.rules(egg: 10_000, neglect: 10)
        rules.hungerDecayPerHour = 100
        let engine = PetEngine(rules: rules)
        let egg = Pet.freshEgg(name: "Pip", at: EngineFixture.start)
        let later = engine.advance(egg, to: EngineFixture.start.addingTimeInterval(5_000))
        XCTAssertEqual(later.stage, .egg)
        XCTAssertFalse(later.isDead)
        XCTAssertNil(later.criticalSince)
    }

    func testGrowthWalksThroughEveryStageAndStopsAtAdult() {
        let rules = EngineFixture.rules()
        let engine = PetEngine(rules: rules)
        let egg = Pet.freshEgg(name: "Pip", at: EngineFixture.start)
        let babyAt = rules.eggDuration
        let childAt = babyAt + rules.babyDuration
        let teenAt = childAt + rules.childDuration
        let adultAt = teenAt + rules.teenDuration

        XCTAssertEqual(engine.advance(egg, to: EngineFixture.start.addingTimeInterval(babyAt)).stage, .baby)
        XCTAssertEqual(engine.advance(egg, to: EngineFixture.start.addingTimeInterval(childAt)).stage, .child)
        XCTAssertEqual(engine.advance(egg, to: EngineFixture.start.addingTimeInterval(teenAt)).stage, .teen)
        let adult = engine.advance(egg, to: EngineFixture.start.addingTimeInterval(adultAt))
        XCTAssertEqual(adult.stage, .adult)
        XCTAssertEqual(adult.stageStartedAt, EngineFixture.start.addingTimeInterval(adultAt))
        let still = engine.advance(egg, to: EngineFixture.start.addingTimeInterval(adultAt + 50_000))
        XCTAssertEqual(still.stage, .adult)
        XCTAssertNil(engine.timeRemainingInStage(still, at: EngineFixture.start.addingTimeInterval(adultAt + 50_000)))
    }
}
