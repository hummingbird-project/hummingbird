// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Benchmarks",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/ordo-one/package-benchmark.git", .upToNextMajor(from: "0.9.0")),
        .package(path: "../../hummingbird"),
    ],
    targets: [
        // Support target having fundamentally verbatim copies of NIOPerformanceTester sources
        .target(
            name: "HBPerformance",
            dependencies: [
                .product(name: "BenchmarkSupport", package: "package-benchmark"),
                .product(name: "Hummingbird", package: "hummingbird")
            ]
        ),

        // Benchmark targets
        .executableTarget(
            name: "HummingbirdBenchmarks",
            dependencies: [
                "HBPerformance",
                .product(name: "BenchmarkSupport", package: "package-benchmark"),
            ],
            path: "Benchmarks/HummingbirdBenchmarks"
        ),
    ]
)
