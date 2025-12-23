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

func urlEncodedFormBenchmarks() {
    Benchmark("URLEncodedForm:Decode", configuration: .init(scalingFactor: .kilo)) { benchmark in
        benchmark.startMeasurement()
        let decoder = URLEncodedFormDecoder()
        struct Test: Codable {
            let test: Int
            let this: UInt32
            let decodes: String
            let arr: [Int]
        }
        for _ in benchmark.scaledIterations {
            try blackHole(decoder.decode(Test.self, from: "test=7&this=23&decodes=true&arr[0]=1&arr[1]=2&arr[2]=3"))
        }
    }

    Benchmark("URLEncodedForm:Encode", configuration: .init(scalingFactor: .kilo)) { benchmark in
        benchmark.startMeasurement()
        let encoder = URLEncodedFormEncoder()
        struct Test: Codable {
            let test: Int
            let this: UInt32
            let decodes: String
            let arr: [Int]
        }
        for _ in benchmark.scaledIterations {
            try blackHole(encoder.encode(Test(test: 5, this: 23, decodes: "whatever", arr: [2, 3, 790])))
        }
    }
}
