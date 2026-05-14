//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import Benchmark
@_spi(Internal) import Hummingbird

func trieRouterBenchmarks() {
    var trie: RouterTrie<String>!
    Benchmark("TrieRouter:Routing", configuration: .init(scalingFactor: .kilo)) { benchmark in
        let testValues = [
            "/test/",
            "/test/one",
            "/test/one/two",
            "/doesntExist",
            "/api/v1/users/1/profile",
        ]
        benchmark.startMeasurement()

        for _ in benchmark.scaledIterations {
            for testValue in testValues {
                blackHole(trie.resolve(testValue))
            }
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
        trie = RouterTrie(base: trieBuilder)
    }

    var trie2: RouterTrie<String>!
    Benchmark("TrieRouter:Parameters", configuration: .init(scalingFactor: .kilo)) { benchmark in
        let testValues = [
            "/test/value",
            "/test/value1/value2",
            "/test2/one/two",
            "/api/v1/users/1/profile",
        ]
        benchmark.startMeasurement()

        for _ in benchmark.scaledIterations {
            for testValue in testValues {
                blackHole(trie2.resolve(testValue))
            }
        }
    } setup: {
        let trieBuilder = RouterPathTrieBuilder<String>()
        trieBuilder.addEntry("/test/:value", value: "/test/:value")
        trieBuilder.addEntry("/test/:value/:value2", value: "/test/:value:/:value2")
        trieBuilder.addEntry("/test2/*/*", value: "/test2/*/*")
        trieBuilder.addEntry("/api/v1/users/:id/profile", value: "/api/v1/users/:id/profile")
        trie2 = RouterTrie(base: trieBuilder)
    }

    var trie3: RouterTrie<String>!
    Benchmark("TrieRouter:LongPaths", configuration: .init(scalingFactor: .kilo)) { benchmark in
        let testValues = [
            "/api/v1/users/1/profile",
            "/api/v1/a/very/long/path/with/lots/of/segments",
        ]
        benchmark.startMeasurement()

        for _ in benchmark.scaledIterations {
            for testValue in testValues {
                blackHole(trie3.resolve(testValue))
            }
        }
    } setup: {
        let trieBuilder = RouterPathTrieBuilder<String>()
        trieBuilder.addEntry("/api/v1/a/very/long/path/with/lots/of/segments", value: "/api/v1/a/very/long/path/with/lots/of/segments")
        trieBuilder.addEntry("/api/v1/users/:id/profile", value: "/api/v1/users/:id/profile")
        trie3 = RouterTrie(base: trieBuilder)
    }
}
