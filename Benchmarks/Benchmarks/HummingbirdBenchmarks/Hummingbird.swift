//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Benchmark
import BenchmarkSupport
import HBPerformance

@main extension BenchmarkRunner {}
@_dynamicReplacement(for: registerBenchmarks)

func benchmarks() {
    Benchmark("Basic Allocations", configuration: .init(metrics: [.mallocCountTotal, .allocatedResidentMemory, .memoryLeaked])) { benchmark in
        try runBenchmark(benchmark: benchmark, running: HBApplicationBenchmarkWrapper(BasicBenchmark()))
    }

    Benchmark("RequestInBody Allocations", configuration: .init(metrics: [.mallocCountTotal, .allocatedResidentMemory, .memoryLeaked])) { benchmark in
        try runBenchmark(benchmark: benchmark, running: HBApplicationBenchmarkWrapper(RequestBodyBenchmark(bufferSize: 100)))
    }

    Benchmark("LargeRequestInBody Allocations", configuration: .init(metrics: [.mallocCountTotal, .allocatedResidentMemory, .memoryLeaked])) { benchmark in
        try runBenchmark(benchmark: benchmark, running: HBApplicationBenchmarkWrapper(RequestBodyBenchmark(bufferSize: 250000)))
    }

    Benchmark("ResponseInBody Allocations", configuration: .init(metrics: [.mallocCountTotal, .allocatedResidentMemory, .memoryLeaked])) { benchmark in
        try runBenchmark(benchmark: benchmark, running: HBApplicationBenchmarkWrapper(ResponseBodyBenchmark(bufferSize: 100)))
    }

    Benchmark("TrieRouter", configuration: .init(metrics: [.wallClock, .mallocCountTotal])) { benchmark in
        try runBenchmark(benchmark: benchmark, running: TrieRouterBenchmark(iterations: 10000))
    }
}

