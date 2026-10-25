// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Momentum",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Momentum", targets: ["Momentum"])],
    targets: [
        .target(name: "MomentumCore"),
        .executableTarget(name: "Momentum", dependencies: ["MomentumCore"]),
        .testTarget(name: "MomentumCoreTests", dependencies: ["MomentumCore"]),
        .testTarget(name: "MomentumInterfaceTests", dependencies: ["Momentum"])
    ]
)
