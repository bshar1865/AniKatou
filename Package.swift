// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AniKatou",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "AniKatou",
            targets: ["AniKatou"]
        )
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "AniKatou",
            dependencies: [
            ],
            path: "AniKatou"
        )
    ]
) 
