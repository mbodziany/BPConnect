// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CubeCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "CubeCore", targets: ["CubeCore"])
    ],
    targets: [
        .target(name: "CubeCore"),
        .testTarget(name: "CubeCoreTests", dependencies: ["CubeCore"])
    ]
)
