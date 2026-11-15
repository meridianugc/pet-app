import XCTest
@testable import PetCore

final class RoomSpaceTests: XCTestCase {
    func testForwardWalkMovesAndWallsStopThePet() {
        let start = FloorPoint(x: 0, z: 0)
        let stepped = RoomSpace.walk(from: start, yaw: 0, stickX: 0, stickY: 1, dt: 0.2)
        XCTAssertTrue(stepped.moving)
        XCTAssertLessThan(stepped.0.z, start.z)
        XCTAssertEqual(stepped.0.x, 0, accuracy: 0.001)

        let against = RoomSpace.walk(from: FloorPoint(x: 0, z: 1.7), yaw: .pi, stickX: 0, stickY: 1, dt: 0.5)
        XCTAssertFalse(RoomSpace.blocked(against.0))
        XCTAssertLessThan(against.0.z, 2.2)
    }

    func testPickupCarryAndBinDropPaysOnce() {
        var room = PlayRoom.starter(looseToy: "toy_comet")
        let toy = room.things.first { $0.id == "toy_comet" }!
        let spot = RoomSpace.floor(from: toy.spot)
        room.pet = RoomSpace.spot(from: spot)
        XCTAssertEqual(RoomSpace.nearestLoose(in: room, at: spot)?.id, "toy_comet")
        room = RoomSpace.pickUp("toy_comet", in: room)!
        XCTAssertNil(RoomSpace.nearestLoose(in: room, at: spot))
        XCTAssertNil(RoomSpace.putDown(in: room, at: FloorPoint(x: 0, z: 0)))
        let dropped = RoomSpace.putDown(in: room, at: RoomSpace.bin)
        XCTAssertEqual(dropped?.reward, RoomRules.tidyGems)
        XCTAssertTrue(dropped?.0.things.first { $0.id == "toy_comet" }?.tucked ?? false)
        XCTAssertNil(RoomSpace.putDown(in: dropped!.0, at: RoomSpace.bin))
    }

    func testTheClosetIsOnlyCloseWhenYouStandAtTheDoors() {
        XCTAssertTrue(RoomSpace.nearCloset(RoomSpace.closet))
        XCTAssertFalse(RoomSpace.nearCloset(FloorPoint(x: 0, z: 0)))
    }
}
