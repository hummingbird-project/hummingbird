// swift-tools-version:6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

var swiftSettings: [SwiftSetting] = [
    // https://github.com/apple/swift-evolution/blob/main/proposals/0335-existential-any.md
    .enableUpcomingFeature("ExistentialAny"),

    // https://github.com/swiftlang/swift-evolution/blob/main/proposals/0444-member-import-visibility.md
    .enableUpcomingFeature("MemberImportVisibility"),

    // https://github.com/swiftlang/swift-evolution/blob/main/proposals/0409-access-level-on-imports.md
    .enableUpcomingFeature("InternalImportsByDefault"),
]

#if compiler(>=6.3)
swiftSettings.append(contentsOf: [
    .enableExperimentalFeature("AvailabilityMacro=hummingbird 2.0:macOS 14.0, iOS 17.0, tvOS 17.0, visionOS 1.0, Android 28")
])
#else
swiftSettings.append(contentsOf: [
    .enableExperimentalFeature("AvailabilityMacro=hummingbird 2.0:macOS 14.0, iOS 17.0, tvOS 17.0, visionOS 1.0")
])
#endif

let package = Package(
    name: "hummingbird",
    platforms: [.macOS(.v11), .iOS(.v15), .macCatalyst(.v15), .tvOS(.v15), .visionOS(.v1)],
    products: [
        .library(name: "Hummingbird", targets: ["Hummingbird"]),
        .library(name: "HummingbirdCore", targets: ["HummingbirdCore"]),
        .library(name: "HummingbirdHTTP2", targets: ["HummingbirdHTTP2"]),
        .library(name: "HummingbirdTLS", targets: ["HummingbirdTLS"]),
        .library(name: "HummingbirdRouter", targets: ["HummingbirdRouter"]),
        .library(name: "HummingbirdTesting", targets: ["HummingbirdTesting"]),
        .executable(name: "PerformanceTest", targets: ["PerformanceTest"]),
    ],
    traits: [
        .trait(name: "ConfigurationSupport", description: "Enable support for swift-configuration package."),
        .default(enabledTraits: ["ConfigurationSupport"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-async-algorithms.git", from: "1.0.2"),
        .package(url: "https://github.com/apple/swift-atomics.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-configuration.git", from: "1.0.2", traits: []),
        .package(url: "https://github.com/apple/swift-distributed-tracing.git", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-http-types.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.11.0"),
        .package(url: "https://github.com/apple/swift-metrics.git", from: "2.5.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.99.0"),
        .package(url: "https://github.com/apple/swift-nio-extras.git", from: "1.20.0"),
        .package(url: "https://github.com/apple/swift-nio-http2.git", from: "1.38.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.14.0"),
        .package(url: "https://github.com/apple/swift-nio-transport-services.git", from: "1.20.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.0.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.30.0"),
    ],
    targets: [
        .target(
            name: "Hummingbird",
            dependencies: [
                .byName(name: "HummingbirdCore"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "Atomics", package: "swift-atomics"),
                .product(name: "Configuration", package: "swift-configuration", condition: .when(traits: ["ConfigurationSupport"])),
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Metrics", package: "swift-metrics"),
                .product(name: "Tracing", package: "swift-distributed-tracing"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOFoundationEssentialsCompat", package: "swift-nio"),
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "HummingbirdCore",
            dependencies: [
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "DequeModule", package: "swift-collections"),
                .product(name: "Configuration", package: "swift-configuration", condition: .when(traits: ["ConfigurationSupport"])),
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOConcurrencyHelpers", package: "swift-nio"),
                .product(name: "NIOHTTPTypes", package: "swift-nio-extras"),
                .product(name: "NIOHTTPTypesHTTP1", package: "swift-nio-extras"),
                .product(name: "NIOExtras", package: "swift-nio-extras"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(
                    name: "NIOTransportServices",
                    package: "swift-nio-transport-services",
                    condition: .when(platforms: [.macOS, .iOS, .macCatalyst, .tvOS, .visionOS])
                ),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "HummingbirdRouter",
            dependencies: [
                .byName(name: "Hummingbird"),
                .product(name: "Logging", package: "swift-log"),
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "HummingbirdTesting",
            dependencies: [
                .byName(name: "Hummingbird"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOConcurrencyHelpers", package: "swift-nio"),
                .product(name: "NIOEmbedded", package: "swift-nio"),
                .product(name: "NIOHTTPTypes", package: "swift-nio-extras"),
                .product(name: "NIOHTTPTypesHTTP1", package: "swift-nio-extras"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "HummingbirdHTTP2",
            dependencies: [
                .byName(name: "HummingbirdCore"),
                .product(name: "Configuration", package: "swift-configuration", condition: .when(traits: ["ConfigurationSupport"])),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOHTTP2", package: "swift-nio-http2"),
                .product(name: "NIOHTTPTypes", package: "swift-nio-extras"),
                .product(name: "NIOHTTPTypesHTTP1", package: "swift-nio-extras"),
                .product(name: "NIOHTTPTypesHTTP2", package: "swift-nio-extras"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "HummingbirdTLS",
            dependencies: [
                .byName(name: "HummingbirdCore"),
                .product(name: "Configuration", package: "swift-configuration", condition: .when(traits: ["ConfigurationSupport"])),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
            ],
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "PerformanceTest",
            dependencies: [
                .byName(name: "Hummingbird"),
                .product(name: "NIOPosix", package: "swift-nio"),
            ],
            swiftSettings: swiftSettings
        ),
        // test targets
        .testTarget(
            name: "HummingbirdTests",
            dependencies: [
                .byName(name: "Hummingbird"),
                .byName(name: "HummingbirdTLS"),
                .byName(name: "HummingbirdHTTP2"),
                .byName(name: "HummingbirdTesting"),
                .byName(name: "HummingbirdRouter"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "HummingbirdRouterTests",
            dependencies: [
                .byName(name: "HummingbirdRouter"),
                .byName(name: "HummingbirdTesting"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "HummingbirdCoreTests",
            dependencies: [
                .byName(name: "HummingbirdCore"),
                .byName(name: "HummingbirdTLS"),
                .byName(name: "HummingbirdTesting"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ],
            resources: [.process("Certificates")],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "HummingbirdHTTP2Tests",
            dependencies: [
                .byName(name: "HummingbirdCore"),
                .byName(name: "HummingbirdHTTP2"),
                .byName(name: "HummingbirdTesting"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ],
            swiftSettings: swiftSettings
        ),
    ]
)

if Context.environment["ENABLE_HB_BENCHMARKS"] != nil {
    package.dependencies.append(
        .package(url: "https://github.com/ordo-one/package-benchmark", from: "1.0.0")
    )
    package.targets.append(
        .executableTarget(
            name: "HummingbirdBenchmarks",
            dependencies: [
                "Hummingbird",
                "HummingbirdRouter",
                .product(name: "Benchmark", package: "package-benchmark"),
            ],
            path: "Benchmarks/HummingbirdBenchmarks",
            swiftSettings: swiftSettings,
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        )
    )
}
