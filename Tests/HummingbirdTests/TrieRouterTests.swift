//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import Testing

@testable @_spi(Internal) import Hummingbird

struct TrieRouterTests {
    @Test func testPathComponentsTrie() {
        let trieBuilder = RouterPathTrieBuilder<String>()
        trieBuilder.addEntry("/usr/local/bin", value: "test1")
        trieBuilder.addEntry("/usr/bin", value: "test2")
        trieBuilder.addEntry("/Users/*/bin", value: "test3")
        let trie = trieBuilder.build()

        #expect(trie.resolve("/usr/local/bin")?.value == "test1")
        #expect(trie.resolve("/usr/bin")?.value == "test2")
        #expect(trie.resolve("/Users/john/bin")?.value == "test3")
        #expect(trie.resolve("/Users/jane/bin")?.value == "test3")
    }

    @Test func testPathParsing() {
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

        #expect(getFirstChildElement("test1") == .capture("param"))
        #expect(getFirstChildElement("test2") == .capture("param"))
        #expect(getFirstChildElement("test3") == .wildcard)
        #expect(getFirstChildElement("test4") == .recursiveWildcard)
        #expect(getFirstChildElement("test5") == .prefixWildcard(".jpg"))
        #expect(getFirstChildElement("test6") == .suffixWildcard("test."))
        #expect(getFirstChildElement("test7") == .prefixCapture(suffix: ".jpg", parameter: "image"))
        #expect(getFirstChildElement("test8") == .suffixCapture(prefix: "test.", parameter: "ext"))
    }

    @Test func testRootNode() {
        let trieBuilder = RouterPathTrieBuilder<String>()
        trieBuilder.addEntry("", value: "test1")
        let trie = trieBuilder.build()
        #expect(trie.resolve("/")?.value == "test1")
        #expect(trie.resolve("")?.value == "test1")
    }

    @Test func testWildcard() {
        let trieBuilder = RouterPathTrieBuilder<String>()
        trieBuilder.addEntry("users/*", value: "test1")
        trieBuilder.addEntry("users/*/fowler", value: "test2")
        trieBuilder.addEntry("users/*/*", value: "test3")
        let trie = trieBuilder.build()
        #expect(trie.resolve("/users") == nil)
        #expect(trie.resolve("/users/adam")?.value == "test1")
        #expect(trie.resolve("/users/adam/fowler")?.value == "test2")
        #expect(trie.resolve("/users/adam/1")?.value == "test3")
    }

    @Test func testGetParameters() {
        let trieBuilder = RouterPathTrieBuilder<String>()
        trieBuilder.addEntry("users/:user", value: "test1")
        trieBuilder.addEntry("users/:user/name", value: "john smith")
        trieBuilder.addEntry("users/:user/name/{id}", value: "41D2DF67-C2C2-4842-B1DA-9F4549BED3F0")
        let trie = trieBuilder.build()
        #expect(trie.resolve("/user/") == nil)
        #expect(trie.resolve("/users/1234")?.parameters.get("user") == "1234")
        #expect(trie.resolve("/users/1234/name")?.parameters.get("user") == "1234")
        #expect(trie.resolve("/users/1234/name")?.value == "john smith")
        #expect(trie.resolve("/users/1234/name/34")?.value == "41D2DF67-C2C2-4842-B1DA-9F4549BED3F0")
        #expect(trie.resolve("/users/5678/name/34")?.parameters.get("user") == "5678")
        #expect(trie.resolve("/users/1234/name/90")?.parameters.get("id") == "90")
    }

    @Test func testRecursiveWildcard() {
        let trieBuilder = RouterPathTrieBuilder<String>()
        trieBuilder.addEntry("**", value: "**")
        let trie = trieBuilder.build()
        #expect(trie.resolve("/one")?.value == "**")
        #expect(trie.resolve("/one/two")?.value == "**")
        #expect(trie.resolve("/one/two/three")?.value == "**")
        #expect(trie.resolve("/one/two/three")?.parameters.getCatchAll() == ["one", "two", "three"])
    }

    @Test func testRecursiveWildcardWithPrefix() {
        let trieBuilder = RouterPathTrieBuilder<String>()
        trieBuilder.addEntry("Test/**", value: "true")
        trieBuilder.addEntry("Test2/:test/**", value: "true")
        let trie = trieBuilder.build()
        #expect(trie.resolve("/notTest/hello") == nil)
        #expect(trie.resolve("/Test/")?.value == nil)
        #expect(trie.resolve("/Test/one")?.value == "true")
        #expect(trie.resolve("/Test/one/two")?.value == "true")
        #expect(trie.resolve("/Test/one/two/three")?.value == "true")
        #expect(trie.resolve("/Test/")?.parameters.getCatchAll() == nil)
        #expect(trie.resolve("/Test/one/two")?.parameters.getCatchAll() == ["one", "two"])
        #expect(trie.resolve("/Test2/one/two")?.parameters.getCatchAll() == ["two"])
        #expect(Parameters().getCatchAll() == [])
    }

    @Test func testPrefixWildcard() {
        let trieBuilder = RouterPathTrieBuilder<String>()
        trieBuilder.addEntry("*.jpg", value: "jpg")
        trieBuilder.addEntry("test/*.jpg", value: "testjpg")
        trieBuilder.addEntry("*.app/config.json", value: "app")
        let trie = trieBuilder.build()
        #expect(trie.resolve("/hello.png") == nil)
        #expect(trie.resolve("/hello.jpg")?.value == "jpg")
        #expect(trie.resolve("/test/hello.jpg")?.value == "testjpg")
        #expect(trie.resolve("/hello.app/config.json")?.value == "app")
    }

    @Test func testSuffixWildcard() {
        let trieBuilder = RouterPathTrieBuilder<String>()
        trieBuilder.addEntry("file.*", value: "file")
        trieBuilder.addEntry("test/file.*", value: "testfile")
        trieBuilder.addEntry("file.*/test", value: "filetest")
        let trie = trieBuilder.build()
        #expect(trie.resolve("/file2.png") == nil)
        #expect(trie.resolve("/file.jpg")?.value == "file")
        #expect(trie.resolve("/test/file.jpg")?.value == "testfile")
        #expect(trie.resolve("/file.png/test")?.value == "filetest")
    }

    @Test func testPrefixCapture() {
        let trieBuilder = RouterPathTrieBuilder<String>()
        trieBuilder.addEntry("{file}.jpg", value: "jpg")
        trieBuilder.addEntry("test/{file}.jpg", value: "testjpg")
        trieBuilder.addEntry("{app}.app/config.json", value: "app")
        let trie = trieBuilder.build()
        #expect(trie.resolve("/hello.png") == nil)
        #expect(trie.resolve("/hello.jpg")?.parameters.get("file") == "hello")
        #expect(trie.resolve("/test/hello.jpg")?.parameters.get("file") == "hello")
        #expect(trie.resolve("/hello.app/config.json")?.parameters.get("app") == "hello")
    }

    @Test func testSuffixCapture() {
        let trieBuilder = RouterPathTrieBuilder<String>()
        trieBuilder.addEntry("file.{ext}", value: "file")
        trieBuilder.addEntry("test/file.{ext}", value: "testfile")
        trieBuilder.addEntry("file.{ext}/test", value: "filetest")
        let trie = trieBuilder.build()
        #expect(trie.resolve("/file2.png") == nil)
        #expect(trie.resolve("/file.jpg")?.parameters.get("ext") == "jpg")
        #expect(trie.resolve("/test/file.jpg")?.parameters.get("ext") == "jpg")
        #expect(trie.resolve("/file.png/test")?.parameters.get("ext") == "png")
    }

    @Test func testPrefixFullComponentCapture() {
        let trieBuilder = RouterPathTrieBuilder<String>()
        trieBuilder.addEntry("{text}", value: "test")
        let trie = trieBuilder.build()
        #expect(trie.resolve("/file.jpg")?.parameters.get("text") == "file.jpg")
    }

    @Test func testIncompletSuffixCapture() {
        let trieBuilder = RouterPathTrieBuilder<String>()
        trieBuilder.addEntry("text}", value: "test")
        let trie = trieBuilder.build()
        #expect(trie.resolve("/text}")?.value == "test")
        #expect(trie.resolve("/text") == nil)
    }

    @Test func testRoutePrecedence() {
        let trieBuilder = RouterPathTrieBuilder<String>()
        trieBuilder.addEntry("path.jpg", value: "path")
        trieBuilder.addEntry("{parameter}", value: "parameter")
        trieBuilder.addEntry("{parameter}.jpg", value: "prefixParameter")
        trieBuilder.addEntry("*.txt", value: "prefixWildcard")
        trieBuilder.addEntry("*", value: "wildcard")
        let trie = trieBuilder.build()
        #expect(trie.resolve("path.jpg")?.value == "path")
        #expect(trie.resolve("this.jpg")?.value == "prefixParameter")
        #expect(trie.resolve("this.txt")?.value == "prefixWildcard")
        #expect(trie.resolve("hello")?.value == "parameter")
    }
}
