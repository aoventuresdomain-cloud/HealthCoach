// swift-tools-version: 6.0
// CoachCore: planner, rules engine, progression and the Claude import parser.
// No iOS dependencies (Foundation only), so `swift test` runs on macOS, Linux
// and in Xcode Cloud. iOS-only frameworks (AlarmKit, HealthKit, ActivityKit,
// SwiftData) stay in the App target behind protocols defined here.
import PackageDescription

let package = Package(
    name: "CoachCore",
    platforms: [
        .iOS("26.0"),
        .macOS(.v14),
    ],
    products: [
        .library(name: "CoachCore", targets: ["CoachCore"]),
    ],
    targets: [
        .target(name: "CoachCore"),
        .testTarget(name: "CoachCoreTests", dependencies: ["CoachCore"]),
    ]
)
