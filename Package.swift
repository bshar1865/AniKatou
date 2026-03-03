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
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "7.10.2")
    ],
    targets: [
        .target(
            name: "AniKatou",
            dependencies: [
                "Kingfisher"
            ],
            path: "AniKatou"
        )
    ]
) 
