// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AndroidFile",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "AndroidFile", targets: ["AndroidFile"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "AndroidFile",
            dependencies: [],
            path: "Sources",
            linkerSettings: []
        )
    ]
)
