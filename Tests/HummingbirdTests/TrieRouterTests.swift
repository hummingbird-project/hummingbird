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

@testable @_spi(Internal) import Hummingbird
import XCTest

class TrieRouterTests: XCTestCase {
    func testPathComponentsTrie() {
        let trieBuilder = RouterPathTrieBuilder<String>()
        trieBuilder.addEntry("/usr/local/bin", value: "test1")
        trieBuilder.addEntry("/usr/bin", value: "test2")
        trieBuilder.addEntry("/Users/*/bin", value: "test3")
        let trie = trieBuilder.build()

        XCTAssertEqual(trie.resolve("/usr/local/bin")?.value, "test1")
        XCTAssertEqual(trie.resolve("/usr/bin")?.value, "test2")
        XCTAssertEqual(trie.resolve("/Users/john/bin")?.value, "test3")
        XCTAssertEqual(trie.resolve("/Users/jane/bin")?.value, "test3")
    }

    func testPathParsing() {
        let trieBuilder = RouterPathTrieBuilder<String>()
        func getFirstChildElement(_ path: String) -> RouterPath.Element? {
            trieBuilder.root.children.first(where: { $0.key == path })?.children.first?.key
        }
        trieBuilder.addEntry("test1/:param", value: "*")
        trieBuilder.addEntry("test2/{param}", value: "*")
        trieBuilder.addEntry("test3/*", value: "*")
        trieBuilder.addEntry("test4/**", value: "*")
        trieBuilder.addEntry("test5/*.jpg", value: "*")
        trieBuilder.addEntry("test6/test.*", value: "*")
        trieBuilder.addEntry("test7/{image}.jpg", value: "*")
        trieBuilder.addEntry("test8/test.{ext}", value: "*")

        XCTAssertEqual(getFirstChildElement("test1"), .capture("param"))
        XCTAssertEqual(getFirstChildElement("test2"), .capture("param"))
        XCTAssertEqual(getFirstChildElement("test3"), .wildcard)
        XCTAssertEqual(getFirstChildElement("test4"), .recursiveWildcard)
        XCTAssertEqual(getFirstChildElement("test5"), .prefixWildcard(".jpg"))
        XCTAssertEqual(getFirstChildElement("test6"), .suffixWildcard("test."))
        XCTAssertEqual(getFirstChildElement("test7"), .prefixCapture(suffix: ".jpg", parameter: "image"))
        XCTAssertEqual(getFirstChildElement("test8"), .suffixCapture(prefix: "test.", parameter: "ext"))
    }

    func testRootNode() {
        let trieBuilder = RouterPathTrieBuilder<String>()
        trieBuilder.addEntry("", value: "test1")
        let trie = trieBuilder.build()
        XCTAssertEqual(trie.resolve("/")?.value, "test1")
        XCTAssertEqual(trie.resolve("")?.value, "test1")
    }

    func testWildcard() {
        let trieBuilder = RouterPathTrieBuilder<String>()
        trieBuilder.addEntry("users/*", value: "test1")
        trieBuilder.addEntry("users/*/fowler", value: "test2")
        trieBuilder.addEntry("users/*/*", value: "test3")
        let trie = trieBuilder.build()
        XCTAssertNil(trie.resolve("/users"))
        XCTAssertEqual(trie.resolve("/users/adam")?.value, "test1")
        XCTAssertEqual(trie.resolve("/users/adam/fowler")?.value, "test2")
        XCTAssertEqual(trie.resolve("/users/adam/1")?.value, "test3")
    }

    func testGetParameters() {
        let trieBuilder = RouterPathTrieBuilder<String>()
        trieBuilder.addEntry("users/:user", value: "test1")
        trieBuilder.addEntry("users/:user/name", value: "john smith")
        let trie = trieBuilder.build()
        XCTAssertNil(trie.resolve("/user/"))
        XCTAssertEqual(trie.resolve("/users/1234")?.parameters.get("user"), "1234")
        XCTAssertEqual(trie.resolve("/users/1234/name")?.parameters.get("user"), "1234")
        XCTAssertEqual(trie.resolve("/users/1234/name")?.value, "john smith")
    }

    func testRecursiveWildcard() {
        let trieBuilder = RouterPathTrieBuilder<String>()
        trieBuilder.addEntry("**", value: "**")
        let trie = trieBuilder.build()
        XCTAssertEqual(trie.resolve("/one")?.value, "**")
        XCTAssertEqual(trie.resolve("/one/two")?.value, "**")
        XCTAssertEqual(trie.resolve("/one/two/three")?.value, "**")
        XCTAssertEqual(trie.resolve("/one/two/three")?.parameters.getCatchAll(), ["one", "two", "three"])
    }

    func testRecursiveWildcardWithPrefix() {
        let trieBuilder = RouterPathTrieBuilder<String>()
        trieBuilder.addEntry("Test/**", value: "true")
        trieBuilder.addEntry("Test2/:test/**", value: "true")
        let trie = trieBuilder.build()
        XCTAssertNil(trie.resolve("/notTest/hello"))
        XCTAssertNil(trie.resolve("/Test/")?.value, "true")
        XCTAssertEqual(trie.resolve("/Test/one")?.value, "true")
        XCTAssertEqual(trie.resolve("/Test/one/two")?.value, "true")
        XCTAssertEqual(trie.resolve("/Test/one/two/three")?.value, "true")
        XCTAssertEqual(trie.resolve("/Test/")?.parameters.getCatchAll(), nil)
        XCTAssertEqual(trie.resolve("/Test/one/two")?.parameters.getCatchAll(), ["one", "two"])
        XCTAssertEqual(trie.resolve("/Test2/one/two")?.parameters.getCatchAll(), ["two"])
        XCTAssertEqual(Parameters().getCatchAll(), [])
    }

    func testPrefixWildcard() {
        let trieBuilder = RouterPathTrieBuilder<String>()
        trieBuilder.addEntry("*.jpg", value: "jpg")
        trieBuilder.addEntry("test/*.jpg", value: "testjpg")
        trieBuilder.addEntry("*.app/config.json", value: "app")
        let trie = trieBuilder.build()
        XCTAssertNil(trie.resolve("/hello.png"))
        XCTAssertEqual(trie.resolve("/hello.jpg")?.value, "jpg")
        XCTAssertEqual(trie.resolve("/test/hello.jpg")?.value, "testjpg")
        XCTAssertEqual(trie.resolve("/hello.app/config.json")?.value, "app")
    }

    func testSuffixWildcard() {
        let trieBuilder = RouterPathTrieBuilder<String>()
        trieBuilder.addEntry("file.*", value: "file")
        trieBuilder.addEntry("test/file.*", value: "testfile")
        trieBuilder.addEntry("file.*/test", value: "filetest")
        let trie = trieBuilder.build()
        XCTAssertNil(trie.resolve("/file2.png"))
        XCTAssertEqual(trie.resolve("/file.jpg")?.value, "file")
        XCTAssertEqual(trie.resolve("/test/file.jpg")?.value, "testfile")
        XCTAssertEqual(trie.resolve("/file.png/test")?.value, "filetest")
    }

    func testPrefixCapture() {
        let trieBuilder = RouterPathTrieBuilder<String>()
        trieBuilder.addEntry("{file}.jpg", value: "jpg")
        trieBuilder.addEntry("test/{file}.jpg", value: "testjpg")
        trieBuilder.addEntry("{app}.app/config.json", value: "app")
        let trie = trieBuilder.build()
        XCTAssertNil(trie.resolve("/hello.png"))
        XCTAssertEqual(trie.resolve("/hello.jpg")?.parameters.get("file"), "hello")
        XCTAssertEqual(trie.resolve("/test/hello.jpg")?.parameters.get("file"), "hello")
        XCTAssertEqual(trie.resolve("/hello.app/config.json")?.parameters.get("app"), "hello")
    }

    func testSuffixCapture() {
        let trieBuilder = RouterPathTrieBuilder<String>()
        trieBuilder.addEntry("file.{ext}", value: "file")
        trieBuilder.addEntry("test/file.{ext}", value: "testfile")
        trieBuilder.addEntry("file.{ext}/test", value: "filetest")
        let trie = trieBuilder.build()
        XCTAssertNil(trie.resolve("/file2.png"))
        XCTAssertEqual(trie.resolve("/file.jpg")?.parameters.get("ext"), "jpg")
        XCTAssertEqual(trie.resolve("/test/file.jpg")?.parameters.get("ext"), "jpg")
        XCTAssertEqual(trie.resolve("/file.png/test")?.parameters.get("ext"), "png")
    }

    func testPrefixFullComponentCapture() {
        let trieBuilder = RouterPathTrieBuilder<String>()
        trieBuilder.addEntry("{text}", value: "test")
        let trie = trieBuilder.build()
        XCTAssertEqual(trie.resolve("/file.jpg")?.parameters.get("text"), "file.jpg")
    }

    func testIncompletSuffixCapture() {
        let trieBuilder = RouterPathTrieBuilder<String>()
        trieBuilder.addEntry("text}", value: "test")
        let trie = trieBuilder.build()
        XCTAssertEqual(trie.resolve("/text}")?.value, "test")
        XCTAssertNil(trie.resolve("/text"))
    }

    func testRoutePrecedence() {
        let trieBuilder = RouterPathTrieBuilder<String>()
        trieBuilder.addEntry("path.jpg", value: "path")
        trieBuilder.addEntry("{parameter}", value: "parameter")
        trieBuilder.addEntry("{parameter}.jpg", value: "prefixParameter")
        trieBuilder.addEntry("*.txt", value: "prefixWildcard")
        trieBuilder.addEntry("*", value: "wildcard")
        let trie = trieBuilder.build()
        XCTAssertEqual(trie.resolve("path.jpg")?.value, "path")
        XCTAssertEqual(trie.resolve("this.jpg")?.value, "prefixParameter")
        XCTAssertEqual(trie.resolve("this.txt")?.value, "prefixWildcard")
        XCTAssertEqual(trie.resolve("hello")?.value, "parameter")
    }
}
