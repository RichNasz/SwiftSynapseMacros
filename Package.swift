// swift-tools-version: 6.2

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "SwiftSynapseMacros",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .visionOS(.v2),
    ],
    products: [
        .library(
            name: "SwiftSynapseMacrosClient",
            targets: ["SwiftSynapseMacrosClient"]
        ),
        .library(
            name: "SwiftSynapseUI",
            targets: ["SwiftSynapseUI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "602.0.0"),
        .package(url: "https://github.com/RichNasz/SwiftLLMToolMacros", branch: "main"),
        .package(url: "https://github.com/RichNasz/SwiftOpenResponsesDSL", branch: "main"),
        .package(url: "https://github.com/RichNasz/SwiftOpenSkills", branch: "main"),
    ],
    targets: [
        .macro(
            name: "SwiftSynapseMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ],
            exclude: ["Examples"]
        ),
        .target(
            name: "SwiftSynapseMacrosClient",
            dependencies: [
                "SwiftSynapseMacros",
                .product(name: "SwiftLLMToolMacros", package: "SwiftLLMToolMacros"),
                .product(name: "SwiftOpenResponsesDSL", package: "SwiftOpenResponsesDSL"),
                .product(name: "SwiftOpenSkills", package: "SwiftOpenSkills"),
                .product(name: "SwiftOpenSkillsResponses", package: "SwiftOpenSkills"),
            ]
        ),
        .target(
            name: "SwiftSynapseUI",
            dependencies: [
                "SwiftSynapseMacrosClient",
            ]
        ),
        .testTarget(
            name: "SwiftSynapseMacrosTests",
            dependencies: [
                "SwiftSynapseMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
