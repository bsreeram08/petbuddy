// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "PetBuddy",
    platforms: [.macOS("13.0")],
    products: [.library(name: "PetCore", targets: ["PetCore"])],
    targets: [
        .target(name: "PetCore", dependencies: []),
        .testTarget(name: "PetCoreTests", dependencies: ["PetCore"]),
    ]
)
