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

/// A sequence that iterates over string components separated by a given character,
/// omitting empty components.
@usableFromInline
struct SplitStringOmittingEmptySequence: Sequence {
    @usableFromInline let base: String
    @usableFromInline let separator: Character

    @inlinable
    init(_ base: String, separator: Character = "/") {
        self.base = base
        self.separator = separator
    }

    @inlinable
    func makeIterator() -> Iterator {
        Iterator(base: base, separator: separator)
    }

    @usableFromInline
    struct Iterator: IteratorProtocol {
        @usableFromInline let base: String
        @usableFromInline let separator: Character
        @usableFromInline let endIndex: String.Index
        @usableFromInline var currentIndex: String.Index

        @inlinable
        init(base: String, separator: Character) {
            self.base = base
            self.separator = separator
            self.endIndex = base.endIndex
            // Skip leading separators
            var index = base.startIndex
            while index < base.endIndex && base[index] == separator {
                base.formIndex(after: &index)
            }
            self.currentIndex = index
        }

        @inlinable
        mutating func next() -> Substring? {
            guard currentIndex < endIndex else { return nil }

            let start = currentIndex
            // Find next separator or end
            while currentIndex < endIndex && base[currentIndex] != separator {
                base.formIndex(after: &currentIndex)
            }

            let component = base[start..<currentIndex]

            // Skip trailing separators
            while currentIndex < endIndex && base[currentIndex] == separator {
                base.formIndex(after: &currentIndex)
            }

            return component
        }
    }
}
