// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TiercadeCore",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .tvOS(.v26)
    ],
    products: [
        .library(name: "TiercadeCore", targets: ["TiercadeCore"])
    ],
    targets: [
        .target(
            name: "TiercadeCore",
            resources: [
                // Explicitly declare README.md as resource to avoid build warnings
                .process("Bundled/README.md")
            ],
            swiftSettings: [
                // Strict concurrency checking for data-race safety
                .enableUpcomingFeature("StrictConcurrency"),
                .unsafeFlags(["-strict-concurrency=complete"])
                // Note: No default MainActor isolation for library code
                // Library remains nonisolated by default for maximum flexibility
            ]
        ),
        .testTarget(
            name: "TiercadeCoreTests",
            dependencies: ["TiercadeCore"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .unsafeFlags(["-strict-concurrency=complete"])
            ]
        )
    ]
)
