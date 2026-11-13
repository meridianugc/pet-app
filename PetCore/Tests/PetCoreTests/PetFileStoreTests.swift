import XCTest
@testable import PetCore

final class PetFileStoreTests: XCTestCase {
    private func makeStore() throws -> PetFileStore {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("petcore-tests-\(UUID().uuidString)", isDirectory: true)
        return PetFileStore(directory: folder)
    }

    func testRoundTripKeepsThePetAndTheDebugClock() throws {
        let store = try makeStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        let now = Date(timeIntervalSince1970: 1_700_000_123.25)
        var pet = Pet.freshEgg(name: "Pip", at: now)
        pet.stage = .child
        pet.bornAt = now.addingTimeInterval(-500)
        pet.hunger = 42.5
        pet.happiness = 11
        pet.energy = 3
        pet.isSleeping = true
        pet.passedOut = true
        pet.criticalSince = now.addingTimeInterval(-20)
        let record = PetRecord(pet: pet, debugTimeOffset: 3600, notificationPromptDismissed: true)

        XCTAssertNil(try store.load())
        try store.save(record)
        let loaded = try XCTUnwrap(try store.load())
        XCTAssertEqual(loaded.schemaVersion, 1)
        XCTAssertEqual(loaded.debugTimeOffset, 3600)
        XCTAssertTrue(loaded.notificationPromptDismissed)
        XCTAssertEqual(loaded.pet.id, pet.id)
        XCTAssertEqual(loaded.pet.name, "Pip")
        XCTAssertEqual(loaded.pet.stage, .child)
        XCTAssertEqual(loaded.pet.hunger, 42.5, accuracy: 0.001)
        XCTAssertEqual(loaded.pet.isSleeping, true)
        XCTAssertEqual(loaded.pet.passedOut, true)
        XCTAssertEqual(loaded.pet.lastSimulatedAt.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(loaded.pet.criticalSince?.timeIntervalSince1970 ?? 0, now.addingTimeInterval(-20).timeIntervalSince1970, accuracy: 0.001)
    }

    func testGarbageAndUnknownSchemasFailClearly() throws {
        let store = try makeStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: store.fileURL)
        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(error as? PetStoreError, .unreadable)
        }

        let saved = PetRecord(pet: Pet.freshEgg(name: "Pip", at: Date(timeIntervalSince1970: 10)))
        try store.save(saved)
        let text = try String(contentsOf: store.fileURL, encoding: .utf8)
        let bumped = text.replacingOccurrences(of: "\"schemaVersion\" : 1", with: "\"schemaVersion\" : 9")
        XCTAssertNotEqual(text, bumped)
        try Data(bumped.utf8).write(to: store.fileURL)
        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(error as? PetStoreError, .unsupportedSchema(9))
        }
    }
}
