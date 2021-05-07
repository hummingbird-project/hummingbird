// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "hummingbird",
    platforms: [.iOS(.v12), .tvOS(.v12)],
    products: [
        .library(name: "Hummingbird", targets: ["Hummingbird"]),
        .library(name: "HummingbirdFoundation", targets: ["HummingbirdFoundation"]),
        .library(name: "HummingbirdXCT", targets: ["HummingbirdXCT"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.4.0"),
        .package(url: "https://github.com/apple/swift-metrics.git", "1.0.0"..<"3.0.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.26.0"),
        .package(url: "https://github.com/apple/swift-nio-extras.git", from: "1.7.0"),
        .package(url: "https://github.com/apple/swift-nio-http2.git", from: "1.16.1"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.4.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.2.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "1.0.0-alpha.6"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-core.git", from: "0.9.0"),
    ],
    targets: [
        .target(name: "Hummingbird", dependencies: [
            .product(name: "HummingbirdCore", package: "hummingbird-core"),
            .product(name: "Lifecycle", package: "swift-service-lifecycle"),
            .product(name: "LifecycleNIOCompat", package: "swift-service-lifecycle"),
            .product(name: "Logging", package: "swift-log"),
            .product(name: "Metrics", package: "swift-metrics"),
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "NIOHTTP1", package: "swift-nio"),
        ]),
        .target(name: "HummingbirdFoundation", dependencies: [
            .byName(name: "Hummingbird"),
            .product(name: "NIOFoundationCompat", package: "swift-nio"),
        ]),
        .target(name: "HummingbirdXCT", dependencies: [
            .byName(name: "Hummingbird"),
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "NIOHTTP1", package: "swift-nio"),
            .product(name: "AsyncHTTPClient", package: "async-http-client"),
        ]),
        .target(name: "PerformanceTest", dependencies: [
            .byName(name: "Hummingbird"),
            .byName(name: "HummingbirdFoundation"),
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
    ]
)
