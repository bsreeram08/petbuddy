// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PetBuddy",
    platforms: [.macOS("13.0")],
    products: [
        .library(name: "PetCore", targets: ["PetCore"]),
        .library(name: "PetPack", targets: ["PetPack"]),
        .library(name: "SpriteSheetRenderer", targets: ["SpriteSheetRenderer"]),
        .library(name: "SlackBotAdapter", targets: ["SlackBotAdapter"]),
        .library(name: "TelegramBotAdapter", targets: ["TelegramBotAdapter"]),
    ],
    dependencies: [
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "4.2.2"),
    ],
    targets: [
        .target(name: "PetCore", dependencies: []),
        .testTarget(name: "PetCoreTests", dependencies: ["PetCore"]),

        .target(name: "PetPack", dependencies: ["PetCore"]),
        .testTarget(name: "PetPackTests", dependencies: ["PetPack"]),

        .target(name: "SpriteSheetRenderer", dependencies: ["PetCore", "PetPack"]),

        .target(name: "SlackBotAdapter", dependencies: ["PetCore"]),
        .target(name: "TelegramBotAdapter", dependencies: ["PetCore"]),

        .target(name: "PetBuddyApp", dependencies: [
            "PetCore", "PetPack", "SpriteSheetRenderer",
            "SlackBotAdapter", "TelegramBotAdapter",
            .product(name: "KeychainAccess", package: "KeychainAccess"),
        ]),
    ]
)
