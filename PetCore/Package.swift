// swift-tools-version: 5.9
// PetCore is plain Foundation so `swift test` can run on Linux and on a Mac.
// Do not import SwiftUI, UIKit, WidgetKit, or UserNotifications here.
import PackageDescription

let package = Package(
    name: "PetCore",
    products: [
        .library(name: "PetCore", targets: ["PetCore"])
    ],
    targets: [
        .target(name: "PetCore"),
        .testTarget(name: "PetCoreTests", dependencies: ["PetCore"])
    ]
)
