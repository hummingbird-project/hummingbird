// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Benchmarks",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/ordo-one/package-benchmark.git", .upToNextMajor(from: "1.0.0")),
        .package(path: "../../hummingbird"),
    ],
    targets: [
        // HTTP1 benchmarks
        .executableTarget(
            name: "HTTP1",
            dependencies: [
                .product(name: "Benchmark", package: "package-benchmark"),
                .product(name: "Hummingbird", package: "hummingbird"),
            ],
            path: "Benchmarks/HTTP1",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark"),
            ]
        ),
        // Router benchmarks
        .executableTarget(
            name: "Router",
            dependencies: [
                .product(name: "Benchmark", package: "package-benchmark"),
                .product(name: "Hummingbird", package: "hummingbird"),
            ],
            path: "Benchmarks/Router",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark"),
            ]
        ),
    ]
)
