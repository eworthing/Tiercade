// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TiercadeCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17)
    ],
    products: [
        .library(name: "TiercadeCore", targets: ["TiercadeCore"]),
    ],
    targets: [
        .target(name: "TiercadeCore"),
        .testTarget(name: "TiercadeCoreTests", dependencies: ["TiercadeCore"]),
    ]
)
