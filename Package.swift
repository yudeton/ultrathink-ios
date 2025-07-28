// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "UltraThink",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "UltraThink",
            targets: ["UltraThink"]),
    ],
    dependencies: [
        // Add package dependencies here if needed
        // .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0"),
    ],
    targets: [
        .target(
            name: "UltraThink",
            dependencies: []),
        .testTarget(
            name: "UltraThinkTests",
            dependencies: ["UltraThink"]),
    ]
)