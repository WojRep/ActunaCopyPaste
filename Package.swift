// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ActunaCopyPaste",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        // Pure-Swift domain core: no AppKit/IO, fully unit-testable (TDD).
        .library(name: "ActunaCopyPasteCore", targets: ["ActunaCopyPasteCore"]),
        // Native Apple-framework adapters (CryptoKit, Security, …) for the core ports.
        .library(name: "ActunaCopyPastePlatform", targets: ["ActunaCopyPastePlatform"]),
        // Shared AppKit/SwiftUI app layer (menu-bar agent, panel, view model,
        // composition root) linked by the App-Full Xcode target.
        .library(name: "ActunaCopyPasteUI", targets: ["ActunaCopyPasteUI"])
    ],
    targets: [
        .target(
            name: "ActunaCopyPasteCore",
            path: "Sources/ActunaCopyPasteCore",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .target(
            name: "ActunaCopyPastePlatform",
            dependencies: ["ActunaCopyPasteCore"],
            path: "Sources/ActunaCopyPastePlatform",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .target(
            name: "ActunaCopyPasteUI",
            dependencies: ["ActunaCopyPasteCore", "ActunaCopyPastePlatform"],
            path: "Sources/ActunaCopyPasteUI",
            resources: [
                // Localized UI strings (en/pl/de/es). System picks the language.
                .process("Resources")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "ActunaCopyPasteCoreTests",
            dependencies: ["ActunaCopyPasteCore"],
            path: "Tests/ActunaCopyPasteCoreTests",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "ActunaCopyPastePlatformTests",
            dependencies: ["ActunaCopyPastePlatform", "ActunaCopyPasteCore"],
            path: "Tests/ActunaCopyPastePlatformTests",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "ActunaCopyPasteUITests",
            dependencies: ["ActunaCopyPasteUI", "ActunaCopyPasteCore", "ActunaCopyPastePlatform"],
            path: "Tests/ActunaCopyPasteUITests",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
