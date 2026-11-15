import PetCore
import SwiftUI
import UIKit

/// Portrait everywhere except Star Defense, which asks for landscape while it is open.
enum PlayOrientation {
    static var mask: UIInterfaceOrientationMask = .portrait

    static func landscape() {
        mask = .landscape
        apply(.landscapeRight)
    }

    static func portrait() {
        mask = .portrait
        apply(.portrait)
    }

    private static func apply(_ orientations: UIInterfaceOrientationMask) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations)) { _ in }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        PlayOrientation.mask
    }
}

@main
struct PocketPetApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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
