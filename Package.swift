// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Murmure",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(
            name: "MurmureSpike",
            targets: ["MurmureSpike"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/sindresorhus/KeyboardShortcuts.git",
            exact: "1.10.0"
        )
    ],
    targets: [
        .executableTarget(
            name: "MurmureSpike",
            dependencies: [
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")
            ]
        )
    ]
)
