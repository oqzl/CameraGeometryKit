// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CameraGeometryKit",
    platforms: [
        .iOS(.v18),
    ],
    products: [
        .library(
            name: "CameraGeometryKit",
            targets: ["CameraGeometryKit"]
        ),
    ],
    targets: [
        .target(
            name: "CameraGeometryKit"
        ),
        .testTarget(
            name: "CameraGeometryKitTests",
            dependencies: ["CameraGeometryKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
