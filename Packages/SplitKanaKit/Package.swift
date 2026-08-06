// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SplitKanaKit",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "SplitKanaKit", targets: ["SplitKanaKit"])
    ],
    targets: [
        .target(name: "SplitKanaKit"),
        .testTarget(name: "SplitKanaKitTests", dependencies: ["SplitKanaKit"])
    ]
)
