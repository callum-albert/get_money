// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EarningsCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "EarningsCore", targets: ["EarningsCore"])],
    targets: [
        .target(name: "EarningsCore"),
        .testTarget(name: "EarningsCoreTests", dependencies: ["EarningsCore"])
    ]
)
