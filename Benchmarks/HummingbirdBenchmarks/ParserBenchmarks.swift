//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import Benchmark
import HummingbirdCore

func parserBenchmarks() {
    let text =
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
    Benchmark("Parser:ReadUntil", configuration: .init(scalingFactor: .kilo)) { benchmark in
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            var parser = Parser(text)
            for _ in 0..<15 {
                try blackHole(parser.read(until: "e"))
            }
        }
    }

    /*    Benchmark("SpanParser:ReadUntil", configuration: .init(scalingFactor: .kilo)) { benchmark in
            if #available(macOS 26, *) {
                benchmark.startMeasurement()
                for _ in benchmark.scaledIterations {
                    var parser = SpanParser(text)
                    for _ in 0..<15 {
                        _ = try parser.read(until: "e")
                    }
                }
            }
        }*/
}
