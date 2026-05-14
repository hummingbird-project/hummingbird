//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import Testing

@testable import Hummingbird

struct SplitStringSequenceTests {
    // MARK: - Basic Splitting

    @Test func basicPathSplitting() {
        let sequence = SplitStringSequence("/a/b/c")
        let components = Array(sequence)
        #expect(components.map(String.init) == ["a", "b", "c"])
    }

    @Test func pathWithoutLeadingSeparator() {
        let sequence = SplitStringSequence("a/b/c")
        let components = Array(sequence)
        #expect(components.map(String.init) == ["a", "b", "c"])
    }

    @Test func trailingSeparatorWithoutLeading() {
        let sequence = SplitStringSequence("a/b/")
        let components = Array(sequence)
        #expect(components.map(String.init) == ["a", "b"])
    }

    @Test func singleComponent() {
        let sequence = SplitStringSequence("component")
        let components = Array(sequence)
        #expect(components.map(String.init) == ["component"])
    }

    @Test func singleComponentWithSeparators() {
        let sequence = SplitStringSequence("/component/")
        let components = Array(sequence)
        #expect(components.map(String.init) == ["component"])
    }

    // MARK: - Empty and Edge Cases

    @Test func emptyString() {
        let sequence = SplitStringSequence("")
        let components = Array(sequence)
        #expect(components.isEmpty)
    }

    @Test func rootPathOnly() {
        let sequence = SplitStringSequence("/")
        let components = Array(sequence)
        #expect(components.isEmpty)
    }

    @Test func multipleSeparatorsOnly() {
        let sequence = SplitStringSequence("///")
        let components = Array(sequence)
        #expect(components.isEmpty)
    }

    // MARK: - Multiple Consecutive Separators

    @Test func multipleConsecutiveSeparatorsInMiddle() {
        let sequence = SplitStringSequence("/a//b///c")
        let components = Array(sequence)
        #expect(components.map(String.init) == ["a", "b", "c"])
    }

    @Test func multipleLeadingSeparators() {
        let sequence = SplitStringSequence("///a/b")
        let components = Array(sequence)
        #expect(components.map(String.init) == ["a", "b"])
    }

    @Test func multipleTrailingSeparators() {
        let sequence = SplitStringSequence("a/b///")
        let components = Array(sequence)
        #expect(components.map(String.init) == ["a", "b"])
    }

    @Test func multipleLeadingAndTrailingSeparators() {
        let sequence = SplitStringSequence("///a/b///")
        let components = Array(sequence)
        #expect(components.map(String.init) == ["a", "b"])
    }

    // MARK: - Custom Separator

    @Test func dotSeparator() {
        let sequence = SplitStringSequence("a.b.c", separator: ".")
        let components = Array(sequence)
        #expect(components.map(String.init) == ["a", "b", "c"])
    }

    @Test func colonSeparator() {
        let sequence = SplitStringSequence(":path:to:resource:", separator: ":")
        let components = Array(sequence)
        #expect(components.map(String.init) == ["path", "to", "resource"])
    }

    @Test func spaceSeparator() {
        let sequence = SplitStringSequence("  hello   world  ", separator: " ")
        let components = Array(sequence)
        #expect(components.map(String.init) == ["hello", "world"])
    }

    @Test func customSeparatorWithMultipleConsecutive() {
        let sequence = SplitStringSequence("a...b..c", separator: ".")
        let components = Array(sequence)
        #expect(components.map(String.init) == ["a", "b", "c"])
    }

    @Test func defaultSeparatorInComponentWithCustomSeparator() {
        let sequence = SplitStringSequence("path/to.file.txt", separator: ".")
        let components = Array(sequence)
        #expect(components.map(String.init) == ["path/to", "file", "txt"])
    }

    // MARK: - Unicode Support

    @Test func unicodePathComponents() {
        let sequence = SplitStringSequence("/hello/世界/мир")
        let components = Array(sequence)
        #expect(components.map(String.init) == ["hello", "世界", "мир"])
    }

    @Test func emojiPathComponents() {
        let sequence = SplitStringSequence("/🎉/🚀/🌟")
        let components = Array(sequence)
        #expect(components.map(String.init) == ["🎉", "🚀", "🌟"])
    }

    @Test func unicodeSeparator() {
        let sequence = SplitStringSequence("a→b→c", separator: "→")
        let components = Array(sequence)
        #expect(components.map(String.init) == ["a", "b", "c"])
    }

    // MARK: - Real-World URL Paths

    @Test func typicalAPIPath() {
        let sequence = SplitStringSequence("/api/v1/users/123/posts")
        let components = Array(sequence)
        #expect(components.map(String.init) == ["api", "v1", "users", "123", "posts"])
    }

    @Test func pathWithQueryLikeComponent() {
        let sequence = SplitStringSequence("/search/query=test")
        let components = Array(sequence)
        #expect(components.map(String.init) == ["search", "query=test"])
    }

    @Test func pathWithSpecialCharacters() {
        let sequence = SplitStringSequence("/path/with-dashes/and_underscores/file.txt")
        let components = Array(sequence)
        #expect(components.map(String.init) == ["path", "with-dashes", "and_underscores", "file.txt"])
    }

    // MARK: - Iterator Behavior

    @Test func iteratorReturnsSubstrings() {
        let path = "/first/second"
        let sequence = SplitStringSequence(path)
        var iterator = sequence.makeIterator()

        let first = iterator.next()
        #expect(first != nil)
        #expect(first! == "first")

        let second = iterator.next()
        #expect(second != nil)
        #expect(second! == "second")

        let third = iterator.next()
        #expect(third == nil)
    }

    @Test func iteratorExhaustion() {
        let sequence = SplitStringSequence("/a")
        var iterator = sequence.makeIterator()

        #expect(iterator.next() != nil)
        #expect(iterator.next() == nil)
        #expect(iterator.next() == nil)  // Should remain nil
    }

    @Test func multipleIteratorsIndependent() {
        let sequence = SplitStringSequence("/a/b/c")

        var iterator1 = sequence.makeIterator()
        var iterator2 = sequence.makeIterator()

        #expect(iterator1.next() == "a")
        #expect(iterator1.next() == "b")
        #expect(iterator2.next() == "a")  // iterator2 is independent
        #expect(iterator1.next() == "c")
        #expect(iterator2.next() == "b")
    }

    // MARK: - Sequence Conformance

    @Test func forInLoopWorks() {
        let sequence = SplitStringSequence("/x/y/z")
        var results: [String] = []
        for component in sequence {
            results.append(String(component))
        }
        #expect(results == ["x", "y", "z"])
    }

    @Test func mapWorks() {
        let sequence = SplitStringSequence("/a/bb/ccc")
        let lengths = sequence.map { $0.count }
        #expect(lengths == [1, 2, 3])
    }

    @Test func filterWorks() {
        let sequence = SplitStringSequence("/short/a/longer/b")
        let longComponents = sequence.filter { $0.count > 1 }.map(String.init)
        #expect(longComponents == ["short", "longer"])
    }

    @Test func reduceWorks() {
        let sequence = SplitStringSequence("/a/b/c")
        let joined = sequence.reduce("") { $0 + String($1) }
        #expect(joined == "abc")
    }

    @Test func countByIterating() {
        let sequence = SplitStringSequence("/a/b/c/d/e")
        var count = 0
        for _ in sequence {
            count += 1
        }
        #expect(count == 5)
    }

    // MARK: - Substring Sharing

    @Test func substringsShareStorageWithOriginal() {
        let path = "/users/profile/settings"
        let sequence = SplitStringSequence(path)
        let components = Array(sequence)

        // Substrings should reference ranges within the original string
        #expect(components[0].base == path)
        #expect(components[1].base == path)
        #expect(components[2].base == path)
    }

    // MARK: - Long Paths

    @Test func longPath() {
        let components = (1...100).map { "segment\($0)" }
        let path = "/" + components.joined(separator: "/")
        let sequence = SplitStringSequence(path)
        let result = Array(sequence).map(String.init)
        #expect(result == components)
    }

    @Test func longComponentNames() {
        let longName = String(repeating: "a", count: 1000)
        let sequence = SplitStringSequence("/\(longName)/\(longName)")
        let components = Array(sequence)
        #expect(components.count == 2)
        #expect(components[0].count == 1000)
        #expect(components[1].count == 1000)
    }

    @Test(arguments: [
        "/test/",
        "test",
        "//test",
        "/test//this",
        "/test/this",
        "/test/this/",
        "/test//this",
        "/test/this//",
        "/test/this/string",
        "/test/this/string/",
        "/test/this/string/works",
        "/test/this/string/works/",
        "/test/this/string/works/fine",
        "/🎉/🚀/🌟",
        "/🎉/🚀/🌟🎉/🚀/🌟",
    ])
    func testSplitStringMaxSplitsSequence(string: String) {
        let split = string.split(separator: "/", maxSplits: 3)
        #expect(split.elementsEqual(string.splitMaxSplitsSequence(separator: "/", maxSplits: 3)))
    }
}
