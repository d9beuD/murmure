// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Murmure",
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
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")
            ]
        )
    ]
)
