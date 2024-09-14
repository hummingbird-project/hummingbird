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
import Foundation
import Hummingbird

let benchmarks = {
    Benchmark.defaultConfiguration = .init(
        metrics: ProcessInfo.processInfo.environment["CI"] != nil ?
        [
            .instructions,
            .mallocCountTotal,
        ] : 
        [
            .cpuTotal,
            .instructions,
            .mallocCountTotal,
        ],
        warmupIterations: 10
    )
    trieRouterBenchmarks()
    routerBenchmarks()
}
