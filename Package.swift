// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "hummingbird",
    platforms: [.macOS(.v10_15)],
    products: [
        .executable(name: "test-framework", targets: ["test-framework"]),
        .library(name: "HummingBird", targets: ["HummingBird"]),
        .library(name: "HBHTTPClient", targets: ["HBHTTPClient"]),
        .library(name: "HBJSON", targets: ["HBJSON"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/swift-backtrace.git", from: "1.1.1"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.4.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.16.1"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.8.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "1.0.0-alpha.6"),
    ],
    targets: [
        .target(name: "test-framework", dependencies: [
            .byName(name: "HummingBird"),
            .byName(name: "HBJSON"),
        ]),
        .target(name: "CURLParser", dependencies: []),
        .target(name: "HummingBird", dependencies: [
            .product(name: "Backtrace", package: "swift-backtrace"),
            .byName(name: "CURLParser"),
            .product(name: "Lifecycle", package: "swift-service-lifecycle"),
            .product(name: "LifecycleNIOCompat", package: "swift-service-lifecycle"),
            .product(name: "Logging", package: "swift-log"),
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "NIOHTTP1", package: "swift-nio"),
        ]),
        .target(name: "HBHTTPClient", dependencies: [
            .byName(name: "HummingBird"),
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "NIOHTTP1", package: "swift-nio"),
            .product(name: "NIOSSL", package: "swift-nio-ssl"),
        ]),
        .target(name: "HBJSON", dependencies: [
            .byName(name: "HummingBird"),
            .product(name: "NIOFoundationCompat", package: "swift-nio"),
        ]),
        // test targets
        .testTarget(name: "HummingBirdTests", dependencies: ["HummingBird"]),
        .testTarget(name: "HBHTTPClientTests", dependencies: ["HBHTTPClient"]),
    ]
)
