// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SIFTMetal",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "SIFTMetal",
            targets: ["SIFTMetal", "MetalShaders"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "MetalShaders",
            resources: [
                .process("Metal")
            ]
        ),
        .target(
            name: "SIFTMetal",
            dependencies: ["MetalShaders"],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .unsafeFlags(["-O"])
            ]
        ),
        .testTarget(
            name: "SIFTMetalTests",
            dependencies: ["SIFTMetal", "MetalShaders"],
            resources: [
                .process("Resources/butterfly.png"),
                .process("Resources/butterfly-descriptors.txt"),

                .process("Resources/extra_OnEdgeResp_butterfly.txt"),

                .process("Resources/scalespace_butterfly_o000_s000.png"),
                .process("Resources/scalespace_butterfly_o000_s001.png"),
                .process("Resources/scalespace_butterfly_o000_s002.png"),
                .process("Resources/scalespace_butterfly_o000_s003.png"),
                .process("Resources/scalespace_butterfly_o000_s004.png"),
                .process("Resources/scalespace_butterfly_o000_s005.png"),
                
                .process("Resources/scalespace_butterfly_o001_s000.png"),
                .process("Resources/scalespace_butterfly_o001_s001.png"),
                .process("Resources/scalespace_butterfly_o001_s002.png"),
                .process("Resources/scalespace_butterfly_o001_s003.png"),
                .process("Resources/scalespace_butterfly_o001_s004.png"),
                .process("Resources/scalespace_butterfly_o001_s005.png"),
                
                .process("Resources/scalespace_butterfly_o002_s000.png"),
                .process("Resources/scalespace_butterfly_o002_s001.png"),
                .process("Resources/scalespace_butterfly_o002_s002.png"),
                .process("Resources/scalespace_butterfly_o002_s003.png"),
                .process("Resources/scalespace_butterfly_o002_s004.png"),
                .process("Resources/scalespace_butterfly_o002_s005.png"),
                
                .process("Resources/scalespace_butterfly_o003_s000.png"),
                .process("Resources/scalespace_butterfly_o003_s001.png"),
                .process("Resources/scalespace_butterfly_o003_s002.png"),
                .process("Resources/scalespace_butterfly_o003_s003.png"),
                .process("Resources/scalespace_butterfly_o003_s004.png"),
                .process("Resources/scalespace_butterfly_o003_s005.png"),
                
                .process("Resources/scalespace_butterfly_o004_s000.png"),
                .process("Resources/scalespace_butterfly_o004_s001.png"),
                .process("Resources/scalespace_butterfly_o004_s002.png"),
                .process("Resources/scalespace_butterfly_o004_s003.png"),
                .process("Resources/scalespace_butterfly_o004_s004.png"),
                .process("Resources/scalespace_butterfly_o004_s005.png"),
]
        ),
    ]
)
