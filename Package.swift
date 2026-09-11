// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "BAR", platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "BARCore", targets: ["BARCore"])],
    targets: [
        .target(name: "BARCore", path: "BARCore", resources: [.process("Data")]),
        .testTarget(name: "BARCoreTests", dependencies: ["BARCore"], path: "Tests/BARCoreTests")
    ]
)
