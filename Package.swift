// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MonocleRadio",
    platforms: [.macOS(.v14), .iOS(.v17), .watchOS(.v10)],
    products: [
        .library(name: "MonocleRadioKit", targets: ["MonocleRadioKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.7.0"),
    ],
    targets: [
        // Shared playback core: models, scraper, audio engine, view model.
        // Consumed by the macOS menu bar app and the iOS app target.
        .target(
            name: "MonocleRadioKit",
            dependencies: ["SwiftSoup"],
            path: "Sources/MonocleRadioKit"
        ),
        // macOS menu bar app
        .executableTarget(
            name: "MonocleRadio",
            dependencies: ["MonocleRadioKit"],
            path: "MonocleRadio",
            exclude: ["Info.plist", "Assets.xcassets"],
            resources: [.copy("Resources")]
        ),
    ]
)
