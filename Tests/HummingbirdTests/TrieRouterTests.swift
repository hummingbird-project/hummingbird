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
import XCTest

class HummingbirdTrieRouterTests: XCTestCase {
    func testPathComponentsTrie() {
        let trie = RouterPathTrie<String>()
        trie.addEntry("/usr/local/bin", value: "test1")
        trie.addEntry("/usr/bin", value: "test2")
        trie.addEntry("/Users/*/bin", value: "test3")

        XCTAssertEqual(trie.getValueAndParameters("/usr/local/bin")?.value, "test1")
        XCTAssertEqual(trie.getValueAndParameters("/usr/bin")?.value, "test2")
        XCTAssertEqual(trie.getValueAndParameters("/Users/john/bin")?.value, "test3")
        XCTAssertEqual(trie.getValueAndParameters("/Users/jane/bin")?.value, "test3")
    }

    func testRootNode() {
        let trie = RouterPathTrie<String>()
        trie.addEntry("", value: "test1")
        XCTAssertEqual(trie.getValueAndParameters("/")?.value, "test1")
        XCTAssertEqual(trie.getValueAndParameters("")?.value, "test1")
    }

    func testWildcard() {
        let trie = RouterPathTrie<String>()
        trie.addEntry("users/*", value: "test1")
        trie.addEntry("users/*/fowler", value: "test2")
        trie.addEntry("users/*/*", value: "test3")
        XCTAssertEqual(trie.getValueAndParameters("/users/adam")?.value, "test1")
        XCTAssertEqual(trie.getValueAndParameters("/users/adam/fowler")?.value, "test2")
        XCTAssertEqual(trie.getValueAndParameters("/users/adam/1")?.value, "test3")
    }

    func testGetParameters() {
        let trie = RouterPathTrie<String>()
        trie.addEntry("users/:user", value: "test1")
        trie.addEntry("users/:user/name", value: "john smith")
        XCTAssertNil(trie.getValueAndParameters("/user/"))
        XCTAssertEqual(trie.getValueAndParameters("/users/1234")?.parameters.get("user"), "1234")
        XCTAssertEqual(trie.getValueAndParameters("/users/1234/name")?.parameters.get("user"), "1234")
        XCTAssertEqual(trie.getValueAndParameters("/users/1234/name")?.value, "john smith")
    }
}
