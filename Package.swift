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
    ],
    targets: [
        .target(name: "PetCore", path: "Packages/PetCore/Sources/PetCore"),
        .testTarget(name: "PetCoreTests", dependencies: ["PetCore"], path: "Packages/PetCore/Tests/PetCoreTests"),

        .target(name: "PetPack", dependencies: ["PetCore"], path: "Packages/PetPack/Sources/PetPack"),
        .testTarget(name: "PetPackTests", dependencies: ["PetPack"], path: "Packages/PetPack/Tests/PetPackTests"),

        .target(name: "SpriteSheetRenderer", dependencies: ["PetCore", "PetPack"], path: "Packages/Renderers/SpriteSheetRenderer/Sources/SpriteSheetRenderer"),

        .target(name: "SlackBotAdapter", dependencies: ["PetCore"], path: "Packages/Integrations/SlackBot/Sources/SlackBotAdapter"),
        .target(name: "TelegramBotAdapter", dependencies: ["PetCore"], path: "Packages/Integrations/TelegramBot/Sources/TelegramBotAdapter"),
    ]
)
