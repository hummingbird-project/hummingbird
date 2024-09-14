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
        // Router benchmarks
        .executableTarget(
            name: "Router",
            dependencies: [
                .product(name: "Benchmark", package: "package-benchmark"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdRouter", package: "hummingbird"),
            ],
            path: "Benchmarks/Router",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark"),
            ]
        ),
    ]
)
