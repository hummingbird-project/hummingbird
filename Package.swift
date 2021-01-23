// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "hummingbird",
    products: [
        .library(name: "Hummingbird", targets: ["Hummingbird"]),
        .library(name: "HummingbirdCore", targets: ["HummingbirdCore"]),
        .library(name: "HummingbirdFiles", targets: ["HummingbirdFiles"]),
        .library(name: "HummingbirdHTTP2", targets: ["HummingbirdHTTP2"]),
        .library(name: "HummingbirdJSON", targets: ["HummingbirdJSON"]),
        .library(name: "HummingbirdTLS", targets: ["HummingbirdTLS"]),
        .library(name: "HummingbirdXCT", targets: ["HummingbirdXCT"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.4.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.16.1"),
        .package(url: "https://github.com/apple/swift-nio-extras.git", from: "1.7.0"),
        .package(url: "https://github.com/apple/swift-nio-http2.git", from: "1.16.1"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.4.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.2.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "1.0.0-alpha.6"),
    ],
    targets: [
        .target(name: "CURLParser", dependencies: []),
        .target(name: "HummingbirdCore", dependencies: [
            .product(name: "Logging", package: "swift-log"),
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "NIOExtras", package: "swift-nio-extras"),
            .product(name: "NIOHTTP1", package: "swift-nio"),
        ]),
        .target(name: "Hummingbird", dependencies: [
            .byName(name: "CURLParser"),
            .byName(name: "HummingbirdCore"),
            .product(name: "Lifecycle", package: "swift-service-lifecycle"),
            .product(name: "LifecycleNIOCompat", package: "swift-service-lifecycle"),
            .product(name: "Logging", package: "swift-log"),
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "NIOHTTP1", package: "swift-nio"),
        ]),
        .target(name: "HummingbirdFiles", dependencies: [
            .byName(name: "Hummingbird"),
            .product(name: "NIO", package: "swift-nio"),
        ]),
        .target(name: "HummingbirdHTTP2", dependencies: [
            .byName(name: "HummingbirdCore"),
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "NIOHTTP2", package: "swift-nio-http2"),
            .product(name: "NIOSSL", package: "swift-nio-ssl"),
        ]),
        .target(name: "HummingbirdJSON", dependencies: [
            .byName(name: "Hummingbird"),
            .product(name: "NIOFoundationCompat", package: "swift-nio"),
        ]),
        .target(name: "HummingbirdTLS", dependencies: [
            .byName(name: "HummingbirdCore"),
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "NIOSSL", package: "swift-nio-ssl"),
        ]),
        .target(name: "HummingbirdXCT", dependencies: [
            .byName(name: "Hummingbird"),
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "NIOHTTP1", package: "swift-nio"),
        ]),
        // test targets
        .testTarget(name: "HummingbirdTests", dependencies: [
            .byName(name: "Hummingbird"),
            .byName(name: "HummingbirdXCT"),
        ]),
        .testTarget(name: "HummingbirdCoreTests", dependencies: [
            .byName(name: "HummingbirdCore"),
            .product(name: "AsyncHTTPClient", package: "async-http-client"),
        ]),
        .testTarget(name: "HummingbirdJSONTests", dependencies: [
            .byName(name: "HummingbirdJSON"),
            .byName(name: "HummingbirdXCT"),
        ]),
        .testTarget(name: "HummingbirdTLSTests", dependencies: [
            .byName(name: "HummingbirdTLS"),
            .product(name: "AsyncHTTPClient", package: "async-http-client"),
        ]),
    ]
)
