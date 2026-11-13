import PetCore
import SwiftUI

@main
struct PocketPetApp: App {
    @StateObject private var session: PetSession
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let directory = PetStorageDirectory.resolve()
        let store = PetFileStore(directory: directory.url)
        _session = StateObject(
            wrappedValue: PetSession(store: store, usesAppGroup: directory.usesAppGroup)
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        session.sceneBecameActive()
                    } else if phase == .background {
                        session.sceneEnteredBackground()
                    }
                }
        }
    }
}
