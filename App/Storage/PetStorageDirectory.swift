import Foundation
import PetCore

/// Finds the folder the app and the widget both read.
/// If the App Group isn't available, the pet is saved in this app only.
struct PetStorageDirectory {
    var url: URL
    var usesAppGroup: Bool

    static func resolve() -> PetStorageDirectory {
        if let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: PetIdentity.appGroupID
        ) {
            return PetStorageDirectory(url: container, usesAppGroup: true)
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return PetStorageDirectory(
            url: base.appendingPathComponent("PocketPet", isDirectory: true),
            usesAppGroup: false
        )
    }
}
