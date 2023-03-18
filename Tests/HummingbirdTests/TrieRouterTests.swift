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

class TrieRouterTests: XCTestCase {
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
        XCTAssertNil(trie.getValueAndParameters("/users"))
        XCTAssertEqual(trie.getValueAndParameters("/users/adam")?.value, "test1")
        XCTAssertEqual(trie.getValueAndParameters("/users/adam/fowler")?.value, "test2")
        XCTAssertEqual(trie.getValueAndParameters("/users/adam/1")?.value, "test3")
    }

    func testGetParameters() {
        let trie = RouterPathTrie<String>()
        trie.addEntry("users/:user", value: "test1")
        trie.addEntry("users/:user/name", value: "john smith")
        XCTAssertNil(trie.getValueAndParameters("/user/"))
        XCTAssertEqual(trie.getValueAndParameters("/users/1234")?.parameters?.get("user"), "1234")
        XCTAssertEqual(trie.getValueAndParameters("/users/1234/name")?.parameters?.get("user"), "1234")
        XCTAssertEqual(trie.getValueAndParameters("/users/1234/name")?.value, "john smith")
    }

    func testRecursiveWildcard() {
        let trie = RouterPathTrie<String>()
        trie.addEntry("**", value: "**")
        XCTAssertEqual(trie.getValueAndParameters("/one")?.value, "**")
        XCTAssertEqual(trie.getValueAndParameters("/one/two")?.value, "**")
        XCTAssertEqual(trie.getValueAndParameters("/one/two/three")?.value, "**")
        XCTAssertEqual(trie.getValueAndParameters("/one/two/three")?.parameters?.getRecursiveCapture(), "one/two/three")
    }

    func testRecursiveWildcardWithPrefix() {
        let trie = RouterPathTrie<String>()
        trie.addEntry("Test/**", value: "true")
        XCTAssertNil(trie.getValueAndParameters("/notTest/hello"))
        XCTAssertNil(trie.getValueAndParameters("/Test/")?.value, "true")
        XCTAssertEqual(trie.getValueAndParameters("/Test/one")?.value, "true")
        XCTAssertEqual(trie.getValueAndParameters("/Test/one/two")?.value, "true")
        XCTAssertEqual(trie.getValueAndParameters("/Test/one/two/three")?.value, "true")
        XCTAssertEqual(trie.getValueAndParameters("/Test/")?.parameters?.getRecursiveCapture(), nil)
        XCTAssertEqual(trie.getValueAndParameters("/Test/one/two")?.parameters?.getRecursiveCapture(), "one/two")
    }

    func testPrefixWildcard() {
        let trie = RouterPathTrie<String>()
        trie.addEntry("*.jpg", value: "jpg")
        trie.addEntry("test/*.jpg", value: "testjpg")
        trie.addEntry("*.app/config.json", value: "app")
        XCTAssertNil(trie.getValueAndParameters("/hello.png"))
        XCTAssertEqual(trie.getValueAndParameters("/hello.jpg")?.value, "jpg")
        XCTAssertEqual(trie.getValueAndParameters("/test/hello.jpg")?.value, "testjpg")
        XCTAssertEqual(trie.getValueAndParameters("/hello.app/config.json")?.value, "app")
    }

    func testSuffixWildcard() {
        let trie = RouterPathTrie<String>()
        trie.addEntry("file.*", value: "file")
        trie.addEntry("test/file.*", value: "testfile")
        trie.addEntry("file.*/test", value: "filetest")
        XCTAssertNil(trie.getValueAndParameters("/file2.png"))
        XCTAssertEqual(trie.getValueAndParameters("/file.jpg")?.value, "file")
        XCTAssertEqual(trie.getValueAndParameters("/test/file.jpg")?.value, "testfile")
        XCTAssertEqual(trie.getValueAndParameters("/file.png/test")?.value, "filetest")
    }

    func testPrefixCapture() {
        let trie = RouterPathTrie<String>()
        trie.addEntry(":file:.jpg", value: "jpg")
        trie.addEntry("test/:file:.jpg", value: "testjpg")
        trie.addEntry(":app:.app/config.json", value: "app")
        XCTAssertNil(trie.getValueAndParameters("/hello.png"))
        XCTAssertEqual(trie.getValueAndParameters("/hello.jpg")?.parameters?.get("file"), "hello")
        XCTAssertEqual(trie.getValueAndParameters("/test/hello.jpg")?.parameters?.get("file"), "hello")
        XCTAssertEqual(trie.getValueAndParameters("/hello.app/config.json")?.parameters?.get("app"), "hello")
    }

    func testSuffixCapture() {
        let trie = RouterPathTrie<String>()
        trie.addEntry("file.:ext:", value: "file")
        trie.addEntry("test/file.:ext:", value: "testfile")
        trie.addEntry("file.:ext:/test", value: "filetest")
        XCTAssertNil(trie.getValueAndParameters("/file2.png"))
        XCTAssertEqual(trie.getValueAndParameters("/file.jpg")?.parameters?.get("ext"), "jpg")
        XCTAssertEqual(trie.getValueAndParameters("/test/file.jpg")?.parameters?.get("ext"), "jpg")
        XCTAssertEqual(trie.getValueAndParameters("/file.png/test")?.parameters?.get("ext"), "png")
    }
}
