// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DesktopMat",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "RugEngine", targets: ["RugEngine"]),
        .executable(name: "DesktopMat", targets: ["DesktopMat"])
    ],
    targets: [
        .target(name: "RugEngine"),
        .executableTarget(
            name: "DesktopMat",
            dependencies: ["RugEngine"],
            resources: [.copy("RugRenderer/Shaders")],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("CoreGraphics")
            ]
        ),
        .testTarget(name: "RugEngineTests", dependencies: ["RugEngine"])
    ]
)
