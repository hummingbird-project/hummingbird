//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2025 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Benchmark
@_spi(Internal) import Hummingbird
import HummingbirdCore

func httpBenchmarks() {
    Benchmark("HTTP:URI:Decode", configuration: .init(scalingFactor: .kilo)) { benchmark in
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            blackHole(URI("/test/this/path?this=true&that=false#end"))
        }
    }

    Benchmark("HTTP:URI:QueryParameters", configuration: .init(scalingFactor: .kilo)) { benchmark in
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            blackHole(URI("/test?this=true&that=false&percent=%45this%48").queryParameters)
        }
    }

    Benchmark("HTTP:Cookie:Decode", configuration: .init(scalingFactor: .kilo)) { benchmark in
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            let cookies = Cookies(from: ["name=value; name2=value2; name3=value3"])
            blackHole(cookies["name"])
        }
    }
}
