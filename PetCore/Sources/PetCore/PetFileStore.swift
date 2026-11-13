import Foundation

public enum PetStoreError: Error, Equatable, Sendable {
    case unreadable
    case unsupportedSchema(Int)
}

/// One JSON file. The app points this at the App Group folder; tests use a temp folder.
public struct PetFileStore: Sendable {
    public let directory: URL
    public let fileURL: URL

    public init(directory: URL, fileName: String = PetIdentity.recordFileName) {
        self.directory = directory
        self.fileURL = directory.appendingPathComponent(fileName)
    }

    public func load() throws -> PetRecord? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw PetStoreError.unreadable
        }
        let record: PetRecord
        do {
            record = try Self.makeDecoder().decode(PetRecord.self, from: data)
        } catch {
            throw PetStoreError.unreadable
        }
        guard record.schemaVersion == PetRecord.currentSchema else {
            throw PetStoreError.unsupportedSchema(record.schemaVersion)
        }
        return record
    }

    public func save(_ record: PetRecord) throws {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try Self.makeEncoder().encode(record)
            try data.write(to: fileURL, options: [.atomic])
        } catch let error as PetStoreError {
            throw error
        } catch {
            throw PetStoreError.unreadable
        }
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }
}
