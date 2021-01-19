// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "hummingbird",
    products: [
        .library(name: "HummingBird", targets: ["HummingBird"]),
        .library(name: "HummingBirdFiles", targets: ["HummingBirdFiles"]),
        .library(name: "HummingBirdJSON", targets: ["HummingBirdJSON"]),
        .library(name: "HummingBirdTLS", targets: ["HummingBirdTLS"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/swift-backtrace.git", from: "1.1.1"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.4.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.16.1"),
        .package(url: "https://github.com/apple/swift-nio-extras.git", from: "1.7.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.4.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.2.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "1.0.0-alpha.6"),
    ],
    targets: [
        .target(name: "CURLParser", dependencies: []),
        .target(name: "HummingBird", dependencies: [
            .product(name: "Backtrace", package: "swift-backtrace"),
            .byName(name: "CURLParser"),
            .product(name: "Lifecycle", package: "swift-service-lifecycle"),
            .product(name: "LifecycleNIOCompat", package: "swift-service-lifecycle"),
            .product(name: "Logging", package: "swift-log"),
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "NIOExtras", package: "swift-nio-extras"),
            .product(name: "NIOHTTP1", package: "swift-nio"),
        ]),
        .target(name: "HummingBirdFiles", dependencies: [
            .byName(name: "HummingBird"),
            .product(name: "NIO", package: "swift-nio"),
        ]),
        .target(name: "HummingBirdJSON", dependencies: [
            .byName(name: "HummingBird"),
            .product(name: "NIOFoundationCompat", package: "swift-nio"),
        ]),
        .target(name: "HummingBirdTLS", dependencies: [
            .byName(name: "HummingBird"),
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "NIOSSL", package: "swift-nio-ssl"),
        ]),
        // test targets
        .testTarget(name: "HummingBirdTests", dependencies: [
            .byName(name: "HummingBird"),
            .product(name: "AsyncHTTPClient", package: "async-http-client"),
        ]),
        .testTarget(name: "HummingBirdJSONTests", dependencies: [
            .byName(name: "HummingBirdJSON"),
            .product(name: "AsyncHTTPClient", package: "async-http-client"),
        ]),
        .testTarget(name: "HummingBirdTLSTests", dependencies: [
            .byName(name: "HummingBirdTLS"),
            .product(name: "AsyncHTTPClient", package: "async-http-client"),
        ]),
    ]
)
