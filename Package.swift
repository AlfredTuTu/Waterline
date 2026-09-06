// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Waterline",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "WaterlineKit", targets: ["WaterlineKit"]),
        .executable(name: "waterline", targets: ["WaterlineCLI"]),
        .executable(name: "WaterlineApp", targets: ["WaterlineApp"]),
    ],
    targets: [
        .target(name: "WaterlineKit"),
        .executableTarget(name: "WaterlineCLI", dependencies: ["WaterlineKit"]),
        .executableTarget(
            name: "WaterlineApp",
            dependencies: ["WaterlineKit"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "WaterlineKitTests",
            dependencies: ["WaterlineKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
