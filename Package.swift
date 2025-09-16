// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TiercadeWorkspace",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v17)
    ],
    dependencies: [
        .package(path: "./TiercadeCore"),
    ],
    targets: [
        .executableTarget(
            name: "Indexer",
            dependencies: ["TiercadeCore"],
            path: "Indexer/Sources/Indexer"
        )
    ]
)
