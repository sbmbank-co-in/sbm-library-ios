// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "sbm-library-ios",
    products: [
        .library(
            name: "sbm-library-ios",
            targets: ["sbm-library-ios"]
        ),
    ],
    targets: [
        .target(
            name: "sbm-library-ios",
            swiftSettings: [
                .define("SWIFT_VERSION_5")
            ]
        ),
        .testTarget(
            name: "sbm-library-iosTests",
            dependencies: ["sbm-library-ios"]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
