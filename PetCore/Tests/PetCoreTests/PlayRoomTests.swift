import XCTest
@testable import PetCore

final class PlayRoomTests: XCTestCase {
    func testAToyOnTheFloorSnapsIntoTheBinAndPaysOnce() {
        var room = PlayRoom.starter(looseToy: "toy_comet")
        let toy = room.things.first { $0.id == "toy_comet" }!
        XCTAssertFalse(toy.tucked)
        let bin = room.furniture.first { $0.id == "bin" }!
        let dropped = RoomRules.drop(toy, at: bin.anchor, in: room)
        XCTAssertTrue(dropped.0.tucked)
        XCTAssertEqual(dropped.0.spot, bin.anchor)
        XCTAssertEqual(dropped.reward, RoomRules.tidyGems)
        let again = RoomRules.drop(dropped.0, at: bin.anchor, in: room)
        XCTAssertEqual(again.reward, 0)
        let missed = RoomRules.drop(toy, at: RoomSpot(x: 0.9, y: 0.12), in: room)
        XCTAssertFalse(missed.0.tucked)
        XCTAssertEqual(missed.reward, 0)
    }

    func testFurnitureSwapCarriesTuckedThingsAndThePetWalks() {
        var room = PlayRoom.starter()
        room = RoomRules.moveFurniture("bin", to: .bed, in: room)
        let bin = room.furniture.first { $0.id == "bin" }!
        XCTAssertEqual(bin.wall, .bed)
        let moon = room.things.first { $0.id == "toy_moon" }!
        XCTAssertEqual(moon.wall, .bed)
        XCTAssertTrue(moon.tucked)
        let bed = room.furniture.first { $0.id == "bed" }!
        XCTAssertEqual(bed.wall, .toys)

        var walking = room
        walking.pet = RoomSpot(x: 0.1, y: 0.1)
        let stepped = RoomRules.stepPet(walking, toward: RoomSpot(x: 0.9, y: 0.1), dt: 0.2)
        XCTAssertGreaterThan(stepped.0.pet.x, walking.pet.x)
        XCTAssertFalse(stepped.arrived)
        let done = RoomRules.stepPet(walking, toward: RoomSpot(x: 0.12, y: 0.1), dt: 1)
        XCTAssertTrue(done.arrived)
    }

    func testLooseToyAndSavedRoomRoundTrip() throws {
        let started = PlayRoom.starter().adoptingLooseToy("toy_comet")
        XCTAssertFalse(started.things.first { $0.id == "toy_comet" }!.tucked)
        let data = try JSONEncoder().encode(started)
        let loaded = try JSONDecoder().decode(PlayRoom.self, from: data)
        XCTAssertEqual(loaded, started)
        var beside = started
        beside.pet = RoomSpot(x: 0.7, y: 0.16)
        beside.petWall = .toys
        XCTAssertEqual(RoomRules.nearbyToy(in: beside)?.id, "toy_comet")
    }

    func testTurningWallsWrapsAround() {
        XCTAssertEqual(RoomWall.toys.next, .closet)
        XCTAssertEqual(RoomWall.window.next, .toys)
        XCTAssertEqual(RoomWall.toys.previous, .window)
    }
}
