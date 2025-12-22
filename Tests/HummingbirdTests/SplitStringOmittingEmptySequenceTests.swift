//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import Hummingbird
import Testing

struct SplitStringOmittingEmptySequenceTests {
    // MARK: - Basic Splitting

    @Test func basicPathSplitting() {
        let sequence = SplitStringOmittingEmptySequence("/a/b/c")
        let components = Array(sequence)
        #expect(components.map(String.init) == ["a", "b", "c"])
    }

    @Test func pathWithoutLeadingSeparator() {
        let sequence = SplitStringOmittingEmptySequence("a/b/c")
        let components = Array(sequence)
        #expect(components.map(String.init) == ["a", "b", "c"])
    }

    @Test func trailingSeparatorWithoutLeading() {
        let sequence = SplitStringOmittingEmptySequence("a/b/")
        let components = Array(sequence)
        #expect(components.map(String.init) == ["a", "b"])
    }

    @Test func singleComponent() {
        let sequence = SplitStringOmittingEmptySequence("component")
        let components = Array(sequence)
        #expect(components.map(String.init) == ["component"])
    }

    @Test func singleComponentWithSeparators() {
        let sequence = SplitStringOmittingEmptySequence("/component/")
        let components = Array(sequence)
        #expect(components.map(String.init) == ["component"])
    }

    // MARK: - Empty and Edge Cases

    @Test func emptyString() {
        let sequence = SplitStringOmittingEmptySequence("")
        let components = Array(sequence)
        #expect(components.isEmpty)
    }

    @Test func rootPathOnly() {
        let sequence = SplitStringOmittingEmptySequence("/")
        let components = Array(sequence)
        #expect(components.isEmpty)
    }

    @Test func multipleSeparatorsOnly() {
        let sequence = SplitStringOmittingEmptySequence("///")
        let components = Array(sequence)
        #expect(components.isEmpty)
    }

    // MARK: - Multiple Consecutive Separators

    @Test func multipleConsecutiveSeparatorsInMiddle() {
        let sequence = SplitStringOmittingEmptySequence("/a//b///c")
        let components = Array(sequence)
        #expect(components.map(String.init) == ["a", "b", "c"])
    }

    @Test func multipleLeadingSeparators() {
        let sequence = SplitStringOmittingEmptySequence("///a/b")
        let components = Array(sequence)
        #expect(components.map(String.init) == ["a", "b"])
    }

    @Test func multipleTrailingSeparators() {
        let sequence = SplitStringOmittingEmptySequence("a/b///")
        let components = Array(sequence)
        #expect(components.map(String.init) == ["a", "b"])
    }

    @Test func multipleLeadingAndTrailingSeparators() {
        let sequence = SplitStringOmittingEmptySequence("///a/b///")
        let components = Array(sequence)
        #expect(components.map(String.init) == ["a", "b"])
    }

    // MARK: - Custom Separator

    @Test func dotSeparator() {
        let sequence = SplitStringOmittingEmptySequence("a.b.c", separator: ".")
        let components = Array(sequence)
        #expect(components.map(String.init) == ["a", "b", "c"])
    }

    @Test func colonSeparator() {
        let sequence = SplitStringOmittingEmptySequence(":path:to:resource:", separator: ":")
        let components = Array(sequence)
        #expect(components.map(String.init) == ["path", "to", "resource"])
    }

    @Test func spaceSeparator() {
        let sequence = SplitStringOmittingEmptySequence("  hello   world  ", separator: " ")
        let components = Array(sequence)
        #expect(components.map(String.init) == ["hello", "world"])
    }

    @Test func customSeparatorWithMultipleConsecutive() {
        let sequence = SplitStringOmittingEmptySequence("a...b..c", separator: ".")
        let components = Array(sequence)
        #expect(components.map(String.init) == ["a", "b", "c"])
    }

    @Test func defaultSeparatorInComponentWithCustomSeparator() {
        let sequence = SplitStringOmittingEmptySequence("path/to.file.txt", separator: ".")
        let components = Array(sequence)
        #expect(components.map(String.init) == ["path/to", "file", "txt"])
    }

    // MARK: - Unicode Support

    @Test func unicodePathComponents() {
        let sequence = SplitStringOmittingEmptySequence("/hello/世界/мир")
        let components = Array(sequence)
        #expect(components.map(String.init) == ["hello", "世界", "мир"])
    }

    @Test func emojiPathComponents() {
        let sequence = SplitStringOmittingEmptySequence("/🎉/🚀/🌟")
        let components = Array(sequence)
        #expect(components.map(String.init) == ["🎉", "🚀", "🌟"])
    }

    @Test func unicodeSeparator() {
        let sequence = SplitStringOmittingEmptySequence("a→b→c", separator: "→")
        let components = Array(sequence)
        #expect(components.map(String.init) == ["a", "b", "c"])
    }

    // MARK: - Real-World URL Paths

    @Test func typicalAPIPath() {
        let sequence = SplitStringOmittingEmptySequence("/api/v1/users/123/posts")
        let components = Array(sequence)
        #expect(components.map(String.init) == ["api", "v1", "users", "123", "posts"])
    }

    @Test func pathWithQueryLikeComponent() {
        let sequence = SplitStringOmittingEmptySequence("/search/query=test")
        let components = Array(sequence)
        #expect(components.map(String.init) == ["search", "query=test"])
    }

    @Test func pathWithSpecialCharacters() {
        let sequence = SplitStringOmittingEmptySequence("/path/with-dashes/and_underscores/file.txt")
        let components = Array(sequence)
        #expect(components.map(String.init) == ["path", "with-dashes", "and_underscores", "file.txt"])
    }

    // MARK: - Iterator Behavior

    @Test func iteratorReturnsSubstrings() {
        let path = "/first/second"
        let sequence = SplitStringOmittingEmptySequence(path)
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
        let sequence = SplitStringOmittingEmptySequence("/a")
        var iterator = sequence.makeIterator()

        #expect(iterator.next() != nil)
        #expect(iterator.next() == nil)
        #expect(iterator.next() == nil) // Should remain nil
    }

    @Test func multipleIteratorsIndependent() {
        let sequence = SplitStringOmittingEmptySequence("/a/b/c")

        var iterator1 = sequence.makeIterator()
        var iterator2 = sequence.makeIterator()

        #expect(iterator1.next() == "a")
        #expect(iterator1.next() == "b")
        #expect(iterator2.next() == "a") // iterator2 is independent
        #expect(iterator1.next() == "c")
        #expect(iterator2.next() == "b")
    }

    // MARK: - Sequence Conformance

    @Test func forInLoopWorks() {
        let sequence = SplitStringOmittingEmptySequence("/x/y/z")
        var results: [String] = []
        for component in sequence {
            results.append(String(component))
        }
        #expect(results == ["x", "y", "z"])
    }

    @Test func mapWorks() {
        let sequence = SplitStringOmittingEmptySequence("/a/bb/ccc")
        let lengths = sequence.map { $0.count }
        #expect(lengths == [1, 2, 3])
    }

    @Test func filterWorks() {
        let sequence = SplitStringOmittingEmptySequence("/short/a/longer/b")
        let longComponents = sequence.filter { $0.count > 1 }.map(String.init)
        #expect(longComponents == ["short", "longer"])
    }

    @Test func reduceWorks() {
        let sequence = SplitStringOmittingEmptySequence("/a/b/c")
        let joined = sequence.reduce("") { $0 + String($1) }
        #expect(joined == "abc")
    }

    @Test func countByIterating() {
        let sequence = SplitStringOmittingEmptySequence("/a/b/c/d/e")
        var count = 0
        for _ in sequence {
            count += 1
        }
        #expect(count == 5)
    }

    // MARK: - Substring Sharing

    @Test func substringsShareStorageWithOriginal() {
        let path = "/users/profile/settings"
        let sequence = SplitStringOmittingEmptySequence(path)
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
        let sequence = SplitStringOmittingEmptySequence(path)
        let result = Array(sequence).map(String.init)
        #expect(result == components)
    }

    @Test func longComponentNames() {
        let longName = String(repeating: "a", count: 1000)
        let sequence = SplitStringOmittingEmptySequence("/\(longName)/\(longName)")
        let components = Array(sequence)
        #expect(components.count == 2)
        #expect(components[0].count == 1000)
        #expect(components[1].count == 1000)
    }
}
