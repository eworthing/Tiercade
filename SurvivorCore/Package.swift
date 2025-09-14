// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SurvivorCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17)
    ],
    products: [
        .library(name: "SurvivorCore", targets: ["SurvivorCore"])
    ],
    targets: [
        .target(name: "SurvivorCore"),
        .testTarget(name: "SurvivorCoreTests", dependencies: ["SurvivorCore"])
    ]
)
