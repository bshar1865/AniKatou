// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "AniKatou",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "AniKatou",
            targets: ["AniKatou"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "AniKatou",
            dependencies: []),
        .testTarget(
            name: "AniKatouTests",
            dependencies: ["AniKatou"]),
    ]
) 