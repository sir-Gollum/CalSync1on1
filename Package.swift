// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "CalSync1on1",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "calsync1on1", targets: ["CalSync1on1"])
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0")
    ],
    targets: [
        .executableTarget(
            name: "CalSync1on1",
            dependencies: ["Yams"]
        ),
        .testTarget(
            name: "CalSync1on1Tests",
            dependencies: ["CalSync1on1"]
        )
    ]
)
