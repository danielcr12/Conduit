// swift-tools-version: 6.0
import PackageDescription
import CompilerPluginSupport
import Foundation

// MARK: - Linux Compatibility
//
// To build on Linux, set the CONDUIT_LINUX environment variable:
//
//   CONDUIT_LINUX=1 swift build
//
// This excludes MLX dependencies which require Metal (Apple-only).
// On Linux, use cloud providers (Anthropic, OpenAI, HuggingFace) or
// local inference via Ollama through the OpenAI provider.
//
// IMPORTANT: The environment variable is evaluated at package resolution time.
// If you switch between Linux and Darwin builds, run:
//
//   swift package reset
//
// This clears cached dependency resolution and ensures correct dependencies.

let excludeMLX = ProcessInfo.processInfo.environment["CONDUIT_LINUX"] != nil

// MARK: - MLX Dependencies (Apple Silicon Only)

let mlxDependencies: [Package.Dependency] = excludeMLX ? [] : [
    .package(url: "https://github.com/ml-explore/mlx-swift.git", from: "0.29.1"),
    .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", from: "2.29.2"),
    .package(url: "https://github.com/ml-explore/mlx-swift-examples.git", revision: "fc3afc7cdbc4b6120d210c4c58c6b132ce346775"),
]

let mlxTargetDependencies: [Target.Dependency] = excludeMLX ? [] : [
    .product(name: "MLX", package: "mlx-swift"),
    .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
    .product(name: "MLXLLM", package: "mlx-swift-lm"),
    .product(name: "MLXVLM", package: "mlx-swift-lm"),
    .product(name: "StableDiffusion", package: "mlx-swift-examples"),
]

// MARK: - Cross-Platform Dependencies

let crossPlatformDependencies: [Package.Dependency] = [
    .package(url: "https://github.com/huggingface/swift-huggingface.git", from: "0.5.0"),
    .package(url: "https://github.com/apple/swift-collections.git", from: "1.1.0"),
    .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
    .package(url: "https://github.com/apple/swift-log.git", from: "1.8.0"),
]

// MARK: - Package Definition

let package = Package(
    name: "Conduit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "Conduit",
            targets: ["Conduit"]
        ),
    ],
    dependencies: crossPlatformDependencies + mlxDependencies,
    targets: [
        .macro(
            name: "ConduitMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
            ],
            path: "Sources/ConduitMacros"
        ),
        .target(
            name: "Conduit",
            dependencies: [
                "ConduitMacros",
                .product(name: "HuggingFace", package: "swift-huggingface"),
                .product(name: "OrderedCollections", package: "swift-collections"),
                .product(name: "Logging", package: "swift-log"),
            ] + mlxTargetDependencies,
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "ConduitTests",
            dependencies: ["Conduit"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "ConduitMacrosTests",
            dependencies: [
                "ConduitMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ],
            path: "Tests/ConduitMacrosTests"
        ),
    ]
)
