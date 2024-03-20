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
@_spi(Internal) import Hummingbird

func trieRouterBenchmarks() {
    var trie: RouterPathTrie<String>!
    Benchmark("TrieRouter", configuration: .init(scalingFactor: .kilo)) { benchmark in
        let testValues = [
            "/test/",
            "/test/one",
            "/test/one/two",
            "/doesntExist",
            "/api/v1/users/1/profile",
        ]
        benchmark.startMeasurement()

        for _ in benchmark.scaledIterations {
            blackHole(testValues.map { trie.getValueAndParameters($0) })
        }
    } setup: {
        let trieBuilder = RouterPathTrieBuilder<String>()
        trieBuilder.addEntry("/test/", value: "/test/")
        trieBuilder.addEntry("/test/one", value: "/test/one")
        trieBuilder.addEntry("/test/one/two", value: "/test/one/two")
        trieBuilder.addEntry("/test/:value", value: "/test/:value")
        trieBuilder.addEntry("/test/:value/:value2", value: "/test/:value:/:value2")
        trieBuilder.addEntry("/api/v1/users/:id/profile", value: "/api/v1/users/:id/profile")
        trieBuilder.addEntry("/test2/*/*", value: "/test2/*/*")
        trie = trieBuilder.build()
    }

    var trie2: RouterPathTrie<String>!
    Benchmark("TrieRouterParameters", configuration: .init(scalingFactor: .kilo)) { benchmark in
        let testValues = [
            "/test/value",
            "/test/value1/value2",
            "/test2/one/two",
            "/api/v1/users/1/profile",
        ]
        benchmark.startMeasurement()

        for _ in benchmark.scaledIterations {
            blackHole(testValues.map { trie2.getValueAndParameters($0) })
        }
    } setup: {
        let trieBuilder = RouterPathTrieBuilder<String>()
        trieBuilder.addEntry("/test/:value", value: "/test/:value")
        trieBuilder.addEntry("/test/:value/:value2", value: "/test/:value:/:value2")
        trieBuilder.addEntry("/test2/*/*", value: "/test2/*/*")
        trieBuilder.addEntry("/api/v1/users/:id/profile", value: "/api/v1/users/:id/profile")
        trie2 = trieBuilder.build()
    }

    var trie3: RouterPathTrie<String>!
    Benchmark("Trie:LongPaths", configuration: .init(scalingFactor: .kilo)) { benchmark in
        let testValues = [
            "/api/v1/users/1/profile",
            "/api/v1/a/very/long/path/with/lots/of/segments",
        ]
        benchmark.startMeasurement()

        for _ in benchmark.scaledIterations {
            blackHole(testValues.map { trie3.getValueAndParameters($0) })
        }
    } setup: {
        let trieBuilder = RouterPathTrieBuilder<String>()
        trieBuilder.addEntry("/api/v1/a/very/long/path/with/lots/of/segments", value: "/api/v1/a/very/long/path/with/lots/of/segments")
        trieBuilder.addEntry("/api/v1/users/:id/profile", value: "/api/v1/users/:id/profile")
        trie3 = trieBuilder.build()
    }
}
