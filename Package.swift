// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SpeakYourMind",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "SpeakYourMind",
            targets: ["SpeakYourMind"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "SpeakYourMind",
            dependencies: ["KeyboardShortcuts"],
            path: "SpeakYourMind",
            exclude: ["Info.plist", "README.md"]
        ),
        .testTarget(
            name: "SpeakYourMindTests",
            dependencies: ["SpeakYourMind"],
            path: "SpeakYourMindTests"
        )
    ]
)