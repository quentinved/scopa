// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Scopa",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ScopaCore", targets: ["ScopaCore"]),
        .library(name: "ScopaMultipeer", targets: ["ScopaMultipeer"]),
        .library(name: "ScopaRewards", targets: ["ScopaRewards"]),
        .library(name: "ScopaGameCenter", targets: ["ScopaGameCenter"]),
        .library(name: "ScopaRelay", targets: ["ScopaRelay"]),
        .library(name: "ScopaProfile", targets: ["ScopaProfile"]),
    ],
    targets: [
        .target(name: "ScopaCore"),
        .target(name: "ScopaMultipeer", dependencies: ["ScopaCore"]),
        .target(name: "ScopaRewards", dependencies: ["ScopaCore"]),
        .target(name: "ScopaGameCenter", dependencies: ["ScopaCore"]),
        .target(name: "ScopaRelay", dependencies: ["ScopaCore"]),
        .target(name: "ScopaProfile"),
        .testTarget(name: "ScopaCoreTests", dependencies: ["ScopaCore"]),
        .testTarget(name: "ScopaRewardsTests", dependencies: ["ScopaRewards"]),
        .testTarget(name: "ScopaRelayTests", dependencies: ["ScopaRelay"]),
        .testTarget(name: "ScopaProfileTests", dependencies: ["ScopaProfile"]),
    ]
)
