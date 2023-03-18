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
import BenchmarkSupport

public func runBenchmark<B: Benchmark>(benchmark: BenchmarkSupport.Benchmark, running: B) throws {
    try running.setUp()
    defer {
        running.tearDown()
    }

    benchmark.startMeasurement()
    blackHole(try running.run())
    benchmark.stopMeasurement()
}
