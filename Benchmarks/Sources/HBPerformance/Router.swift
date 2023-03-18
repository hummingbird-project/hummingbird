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

@testable import Hummingbird

/// Benchmark TrieRouter
public class TrieRouterBenchmark: BenchmarkWrapper {
    let iterations: Int
    let trie = RouterPathTrie<String>()

    public init(iterations: Int) {
        self.iterations = iterations
    }

    public func setUp() throws {
        trie.addEntry("/test/", value: "/test/")
        trie.addEntry("/test/one", value: "/test/one")
        trie.addEntry("/test/one/two", value: "/test/one/two")
        trie.addEntry("/test/:value:", value: "/test/:value:")
        trie.addEntry("/test/:value:/:value2:", value: "/test/:value:/:value2:")
        trie.addEntry("/test2/*/*", value: "/test2/*/*")

        // warmup
        for _ in 0..<100 {
            try singleIteration()
        }

        _ = trie.getValueAndParameters("/test/")
    }

    public func run() throws {
        for _ in 0..<self.iterations {
            try singleIteration()
        }
    }

    func singleIteration() throws {
        _ = trie.getValueAndParameters("/test/")
        _ = trie.getValueAndParameters("/test/one")
        _ = trie.getValueAndParameters("/test/one/two")
        _ = trie.getValueAndParameters("/test/value")
        _ = trie.getValueAndParameters("/test/value1/value2")
        _ = trie.getValueAndParameters("/test2/one/two")
    }
}