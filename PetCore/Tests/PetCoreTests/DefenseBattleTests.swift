import XCTest
@testable import PetCore

final class DefenseBattleTests: XCTestCase {
    func testTowersCannotSitOnThePathAndUpgradesShareTwoPaths() {
        var battle = DefensePlay.start(map: 1, difficulty: .medium)
        XCTAssertFalse(DefensePlay.canPlace(DefensePlay.map(1).path[1], in: battle))
        let grass = openGrass(in: battle)
        battle = DefensePlay.place(.dart, at: grass, petLevel: 8, in: battle)!
        XCTAssertEqual(battle.guns.count, 1)
        XCTAssertNil(DefensePlay.place(.sniper, at: grass, petLevel: 1, in: battle))
        let id = battle.guns[0].id
        battle.cash = 5_000
        for _ in 0..<3 {
            battle = DefensePlay.train(id, pathA: true, in: battle)!
        }
        XCTAssertEqual(battle.guns[0].pathA, 3)
        battle = DefensePlay.train(id, pathA: false, in: battle)!
        battle = DefensePlay.train(id, pathA: false, in: battle)!
        XCTAssertEqual(battle.guns[0].pathB, 2)
        XCTAssertNil(DefensePlay.train(id, pathA: false, in: battle))
        let sold = DefensePlay.sell(id, in: battle)
        XCTAssertEqual(sold?.guns.count, 0)
        XCTAssertGreaterThan(sold?.cash ?? 0, battle.cash)
    }

    func testABigBlobSplitsAndArmorOrCamoCanBlockAShot() {
        var battle = DefensePlay.start(map: 1, difficulty: .easy)
        let spot = DefensePlay.point(on: DefensePlay.map(1).path, distance: 0.45)
        battle.guns = [DefenseGun(id: 1, kind: .bomb, x: spot.x, y: spot.y, pathA: 3, cooldown: 0)]
        battle.nextID = 2
        battle.running = true
        battle.queue = [Blob(id: -1, sort: .plain, layers: 1)]
        battle.blobs = [Blob(id: 40, sort: .plain, layers: 4, distance: 0.45)]
        let popped = DefensePlay.step(battle, dt: 0.02).0
        XCTAssertEqual(popped.blobs.filter { $0.id != 40 && $0.layers == 1 }.count, 2)

        var dart = DefensePlay.start(map: 1, difficulty: .easy)
        dart.guns = [DefenseGun(id: 1, kind: .dart, x: spot.x, y: spot.y, cooldown: 0)]
        dart.nextID = 2
        dart.running = true
        dart.queue = [Blob(id: -2, sort: .plain, layers: 1)]
        dart.blobs = [Blob(id: 7, sort: .armored, layers: 3, distance: 0.45)]
        let ignored = DefensePlay.step(dart, dt: 0.05).0
        XCTAssertEqual(ignored.blobs.first { $0.id == 7 }?.layers, 3)

        dart.blobs = [Blob(id: 8, sort: .camo, layers: 2, distance: 0.45)]
        dart.guns[0].cooldown = 0
        let hidden = DefensePlay.step(dart, dt: 0.05).0
        XCTAssertEqual(hidden.blobs.first { $0.id == 8 }?.layers, 2)
        var revealed = hidden
        revealed.guns[0].pathB = 1
        revealed.guns[0].cooldown = 0
        revealed.running = true
        revealed.queue = [Blob(id: -3, sort: .plain, layers: 1)]
        let hit = DefensePlay.step(revealed, dt: 0.05).0
        XCTAssertNotEqual(hit.blobs.first { $0.id == 8 }?.layers, 2)
    }

    func testAClearedRoundPaysTheFarmAndALeakCostsLives() {
        var battle = DefensePlay.start(map: 1, difficulty: .medium)
        let grass = openGrass(in: battle)
        battle = DefensePlay.place(.farm, at: grass, petLevel: 1, in: battle)!
        let cash = battle.cash
        battle.running = true
        let paid = DefensePlay.step(battle, dt: 0.1).0
        XCTAssertGreaterThan(paid.cash, cash)
        XCTAssertEqual(paid.round, 2)
        XCTAssertFalse(paid.running)

        var leaking = DefensePlay.start(map: 2, difficulty: .hard)
        leaking.running = true
        leaking.blobs = [Blob(id: 3, sort: .plain, layers: 2, distance: 0.98)]
        let lost = DefensePlay.step(leaking, dt: 0.5).0
        XCTAssertLessThan(lost.lives, leaking.lives)

        XCTAssertTrue(DefensePlay.spawns(forRound: 40).contains(.boss))
        XCTAssertTrue(DefensePlay.spawns(forRound: 60).contains(.boss))
        XCTAssertFalse(DefensePlay.spawns(forRound: 10).contains(.boss))
        XCTAssertEqual(DefensePlay.spawns(forRound: 1).count, 8)
        XCTAssertGreaterThan(DefensePlay.spawns(forRound: 61).count, 8)
        XCTAssertEqual(DefensePlay.guns(forPetLevel: 1), [.dart, .farm])
        XCTAssertFalse(DefensePlay.isOpen(map: 2, petLevel: 5, stars: [:]))
        XCTAssertTrue(DefensePlay.isOpen(map: 2, petLevel: 5, stars: [1: 1]))
        XCTAssertEqual(DefenseBattle.roundCount, 60)
        XCTAssertEqual(DefenseDifficulty.easy.authoredRounds, 40)
        XCTAssertEqual(DefenseDifficulty.medium.authoredRounds, 60)
    }

    func testABlobAtEveryDistanceSitsOnTheDrawnPath() {
        let path = DefensePlay.map(1).path
        let start = DefensePlay.point(on: path, distance: 0)
        XCTAssertEqual(start.x, path[0].x, accuracy: 0.000_1)
        XCTAssertEqual(start.y, path[0].y, accuracy: 0.000_1)
        for distance in [0.1, 0.35, 0.55, 0.8, 1.0] {
            let spot = DefensePlay.point(on: path, distance: distance)
            XCTAssertLessThan(DefensePlay.distance(spot, to: path), 0.02, "distance \(distance)")
        }
        let mid = DefensePlay.point(on: path, distance: 0.5)
        let straight = DefensePoint(
            x: (path[0].x + path[path.count - 1].x) / 2,
            y: (path[0].y + path[path.count - 1].y) / 2
        )
        XCTAssertGreaterThan(hypot(mid.x - straight.x, mid.y - straight.y), 0.04)
    }

    func testTheHeroBlastPopsAndThenWaits() {
        var battle = DefensePlay.start(map: 1, difficulty: .easy)
        battle.running = true
        battle.blobs = [Blob(id: 1, sort: .plain, layers: 3, distance: 0.2)]
        let blasted = DefensePlay.heroBlast(battle)
        XCTAssertEqual(blasted?.0.blobs.first?.layers, 1)
        XCTAssertGreaterThan(blasted?.0.heroCooldown ?? 0, 0)
        XCTAssertNil(DefensePlay.heroBlast(blasted!.0))
    }

    private func openGrass(in battle: DefenseBattle) -> DefensePoint {
        for x in stride(from: 0.08, through: 0.9, by: 0.05) {
            for y in stride(from: 0.1, through: 0.9, by: 0.05) {
                let spot = DefensePoint(x: x, y: y)
                if DefensePlay.canPlace(spot, in: battle) { return spot }
            }
        }
        return DefensePoint(x: 0.08, y: 0.9)
    }
}
