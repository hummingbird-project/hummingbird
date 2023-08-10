// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "hummingbird",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13)],
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
        .package(url: "https://github.com/apple/swift-distributed-tracing.git", from: "1.0.1"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.56.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.0.0-alpha"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-core.git", branch: "2.x.x"),
    ],
    targets: [
        .target(name: "Hummingbird", dependencies: [
            .product(name: "HummingbirdCore", package: "hummingbird-core"),
            .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
            .product(name: "Logging", package: "swift-log"),
            .product(name: "Metrics", package: "swift-metrics"),
            .product(name: "Tracing", package: "swift-distributed-tracing"),
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
            .product(name: "Logging", package: "swift-log"),
        ]),
        .target(name: "HummingbirdXCT", dependencies: [
            .byName(name: "Hummingbird"),
            .product(name: "HummingbirdCoreXCT", package: "hummingbird-core"),
            .product(name: "NIOCore", package: "swift-nio"),
            .product(name: "NIOEmbedded", package: "swift-nio"),
            .product(name: "NIOPosix", package: "swift-nio"),
            .product(name: "NIOHTTP1", package: "swift-nio"),
        ]),
        .executableTarget(name: "PerformanceTest", dependencies: [
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
