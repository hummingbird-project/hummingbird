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
        self.trie.addEntry("/test/", value: "/test/")
        self.trie.addEntry("/test/one", value: "/test/one")
        self.trie.addEntry("/test/one/two", value: "/test/one/two")
        self.trie.addEntry("/test/:value:", value: "/test/:value:")
        self.trie.addEntry("/test/:value:/:value2:", value: "/test/:value:/:value2:")
        self.trie.addEntry("/test2/*/*", value: "/test2/*/*")

        // warmup
        for _ in 0..<100 {
            try self.singleIteration()
        }

        _ = self.trie.getValueAndParameters("/test/")
    }

    public func run() throws {
        for _ in 0..<self.iterations {
            try self.singleIteration()
        }
    }

    func singleIteration() throws {
        _ = self.trie.getValueAndParameters("/test/")
        _ = self.trie.getValueAndParameters("/test/one")
        _ = self.trie.getValueAndParameters("/test/one/two")
        _ = self.trie.getValueAndParameters("/test/value")
        _ = self.trie.getValueAndParameters("/test/value1/value2")
        _ = self.trie.getValueAndParameters("/test2/one/two")
        _ = self.trie.getValueAndParameters("/doesntExist")
    }
}
