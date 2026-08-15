// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Entrevoix",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(
            name: "Entrevoix",
            targets: ["Entrevoix"]
        ),
        .library(
            name: "EntrevoixCore",
            targets: ["EntrevoixCore"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/sindresorhus/KeyboardShortcuts.git",
            exact: "1.10.0"
        ),
        .package(
            url: "https://github.com/sparkle-project/Sparkle",
            exact: "2.9.5"
        )
    ],
    targets: [
        .target(
            name: "EntrevoixCore"
        ),
        .executableTarget(
            name: "Entrevoix",
            dependencies: [
                "EntrevoixCore",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                .product(name: "Sparkle", package: "Sparkle")
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "EntrevoixCoreTests",
            dependencies: ["EntrevoixCore"]
        ),
        .testTarget(
            name: "EntrevoixTests",
            dependencies: ["Entrevoix", "EntrevoixCore"]
        )
    ]
)
