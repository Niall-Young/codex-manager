// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CodexManager",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "CodexManager", targets: ["CodexManagerApp"]),
        .executable(name: "CodexManagerSelfTest", targets: ["CodexManagerSelfTest"]),
        .library(name: "CodexManagerCore", targets: ["CodexManagerCore"])
    ],
    targets: [
        .target(
            name: "CodexManagerCore",
            path: "Sources/CodexManagerCore"
        ),
        .executableTarget(
            name: "CodexManagerApp",
            dependencies: ["CodexManagerCore"],
            path: "Sources/CodexManagerApp",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "CodexManagerSelfTest",
            dependencies: ["CodexManagerCore"],
            path: "Sources/CodexManagerSelfTest"
        )
    ]
)
