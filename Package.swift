// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "hummingbird",
    platforms: [.macOS(.v10_15)],
    products: [
        .executable(name: "test-framework", targets: ["test-framework"]),
        .library(name: "HummingBird", targets: ["HummingBird"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/swift-backtrace.git", from: "1.1.1"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.4.0"),
        .package(url: "https://github.com/apple/swift-nio.git", .upToNextMajor(from: "2.16.1")),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "1.0.0-alpha.6"),
    ],
    targets: [
        .target(name: "test-framework", dependencies: [
            .byName(name: "HummingBird"),
        ]),
        .target(name: "HummingBird", dependencies: [
            .product(name: "Backtrace", package: "swift-backtrace"),
            .product(name: "Lifecycle", package: "swift-service-lifecycle"),
            .product(name: "LifecycleNIOCompat", package: "swift-service-lifecycle"),
            .product(name: "Logging", package: "swift-log"),
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "NIOHTTP1", package: "swift-nio"),
        ]),
        .testTarget(name: "HummingBirdTests", dependencies: ["HummingBird"]),
    ]
)
