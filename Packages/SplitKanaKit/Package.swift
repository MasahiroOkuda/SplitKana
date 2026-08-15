// swift-tools-version: 5.9
import PackageDescription

// SplitKanaCore は Foundation だけに依存する。UI も UIKit も入れない。
// そのおかげで Mac 以外（Windows / Linux）でも swift test が走る。
let package = Package(w
    name: "SplitKanaKit",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "SplitKanaCore", targets: ["SplitKanaCore"]),
        .library(name: "SplitKanaUI", targets: ["SplitKanaUI"])
    ],
    targets: [
        .target(name: "SplitKanaCore"),
        .target(name: "SplitKanaUI", dependencies: ["SplitKanaCore"]),
        .testTarget(name: "SplitKanaCoreTests", dependencies: ["SplitKanaCore"])
    ]
)
