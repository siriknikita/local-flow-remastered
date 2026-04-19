// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LocalFlow",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.99.0"),
    ],
    targets: [
        .executableTarget(
            name: "LocalFlow",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
            ],
            path: "Sources",
            exclude: ["App/Info.plist", "App/AppIcon.icns"]
        ),
        .testTarget(
            name: "LocalFlowTests",
            dependencies: ["LocalFlow"],
            path: "Tests"
        ),
    ]
)
