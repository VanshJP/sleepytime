// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SleepCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SleepCore", targets: ["SleepCore"])
    ],
    targets: [
        .target(name: "SleepCore"),
        .testTarget(name: "SleepCoreTests", dependencies: ["SleepCore"])
    ]
)
