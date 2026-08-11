// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Murmure",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(
            name: "Murmure",
            targets: ["Murmure"]
        ),
        .library(
            name: "MurmureCore",
            targets: ["MurmureCore"]
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
            name: "MurmureCore"
        ),
        .executableTarget(
            name: "Murmure",
            dependencies: [
                "MurmureCore",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                .product(name: "Sparkle", package: "Sparkle")
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "MurmureCoreTests",
            dependencies: ["MurmureCore"]
        ),
        .testTarget(
            name: "MurmureTests",
            dependencies: ["Murmure", "MurmureCore"]
        )
    ]
)
