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
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "8.0.0"),
        .package(url: "https://github.com/mrdepth/SwiftSubtitles.git", from: "1.0.0"),
        .package(url: "https://github.com/kean/Nuke.git", from: "12.0.0")
    ],
    targets: [
        .target(
            name: "AniKatou",
            dependencies: [
                "Kingfisher",
                "SwiftSubtitles",
                "Nuke"
            ],
            path: "AniKatou"
        )
    ]
) 