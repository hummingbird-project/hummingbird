//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import Benchmark
import Foundation
import Hummingbird

let benchmarks: @Sendable () -> Void = {
    Benchmark.defaultConfiguration = .init(
        metrics: ProcessInfo.processInfo.environment["CI"] != nil
            ? [
                .instructions,
                .mallocCountTotal,
            ]
            : [
                .cpuTotal,
                .instructions,
                .mallocCountTotal,
            ],
        warmupIterations: 10
    )
    trieRouterBenchmarks()
    routerBenchmarks()
    httpBenchmarks()
    urlEncodedFormBenchmarks()
}
