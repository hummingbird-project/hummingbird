// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "hummingbird",
    platforms: [.iOS(.v12), .tvOS(.v12)],
    products: [
        .library(name: "Hummingbird", targets: ["Hummingbird"]),
        .library(name: "HummingbirdFoundation", targets: ["HummingbirdFoundation"]),
        .library(name: "HummingbirdJobs", targets: ["HummingbirdJobs"]),
        .library(name: "HummingbirdXCT", targets: ["HummingbirdXCT"]),
        .executable(name: "PerformanceTest", targets: ["PerformanceTest"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.4.0"),
        .package(url: "https://github.com/apple/swift-metrics.git", "1.0.0"..<"3.0.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.33.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "1.0.0-alpha.9"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-core.git", .upToNextMinor(from: "0.12.1")),
    ],
    targets: [
        .target(name: "Hummingbird", dependencies: [
            .product(name: "HummingbirdCore", package: "hummingbird-core"),
            .product(name: "Lifecycle", package: "swift-service-lifecycle"),
            .product(name: "LifecycleNIOCompat", package: "swift-service-lifecycle"),
            .product(name: "Logging", package: "swift-log"),
            .product(name: "Metrics", package: "swift-metrics"),
            .product(name: "NIOCore", package: "swift-nio"),
            .product(name: "NIOPosix", package: "swift-nio"),
            .product(name: "NIOHTTP1", package: "swift-nio"),
        ]),
        .target(name: "HummingbirdFoundation", dependencies: [
            .byName(name: "Hummingbird"),
            .product(name: "NIOCore", package: "swift-nio"),
            .product(name: "NIOPosix", package: "swift-nio"),
            .product(name: "NIOFoundationCompat", package: "swift-nio"),
        ]),
        .target(name: "HummingbirdJobs", dependencies: [
            .byName(name: "Hummingbird"),
        ]),
        .target(name: "HummingbirdXCT", dependencies: [
            .byName(name: "Hummingbird"),
            .product(name: "HummingbirdCoreXCT", package: "hummingbird-core"),
            .product(name: "NIOCore", package: "swift-nio"),
            .product(name: "NIOEmbedded", package: "swift-nio"),
            .product(name: "NIOPosix", package: "swift-nio"),
            .product(name: "NIOHTTP1", package: "swift-nio"),
        ]),
        .target(name: "PerformanceTest", dependencies: [
            .byName(name: "Hummingbird"),
            .byName(name: "HummingbirdFoundation"),
            .product(name: "NIOPosix", package: "swift-nio"),
        ]),
        // test targets
        .testTarget(name: "HummingbirdTests", dependencies: [
            .byName(name: "Hummingbird"),
            .byName(name: "HummingbirdFoundation"),
            .byName(name: "HummingbirdXCT"),
        ]),
        .testTarget(name: "HummingbirdFoundationTests", dependencies: [
            .byName(name: "HummingbirdFoundation"),
            .byName(name: "HummingbirdXCT"),
        ]),
        .testTarget(name: "HummingbirdJobsTests", dependencies: [
            .byName(name: "HummingbirdJobs"),
            .byName(name: "HummingbirdXCT"),
        ]),
    ]
)
