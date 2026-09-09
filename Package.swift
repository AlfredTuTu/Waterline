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
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.6")],
    targets: [
        .target(name: "WaterlineKit"),
        .executableTarget(name: "WaterlineCLI", dependencies: ["WaterlineKit"]),
        .executableTarget(
            name: "WaterlineApp",
            dependencies: ["WaterlineKit", .product(name: "Sparkle", package: "Sparkle")],
            swiftSettings: [.defaultIsolation(MainActor.self)],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .testTarget(
            name: "WaterlineKitTests",
            dependencies: ["WaterlineKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
