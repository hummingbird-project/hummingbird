//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

/// A sequence that iterates over string components separated by a given character,
/// omitting empty components.
@usableFromInline
struct SplitStringSequence<S: StringProtocol>: Sequence {
    @usableFromInline let base: S
    @usableFromInline let separator: Character

    @inlinable
    init(_ base: S, separator: Character = "/") {
        self.base = base
        self.separator = separator
    }

    @inlinable
    func makeIterator() -> Iterator {
        Iterator(base: base, separator: separator)
    }

    @usableFromInline
    struct Iterator: IteratorProtocol {
        @usableFromInline let base: S
        @usableFromInline let endIndex: S.Index
        @usableFromInline var currentIndex: S.Index
        @usableFromInline let separator: Character

        @inlinable
        init(base: S, separator: Character) {
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
        mutating func next() -> S.SubSequence? {
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

/// A sequence that iterates over string components separated by a given character,
/// omitting empty components.
@usableFromInline
struct SplitStringMaxSplitsSequence<S: StringProtocol>: Sequence {
    @usableFromInline let base: S
    @usableFromInline let separator: Character
    @usableFromInline let maxSplits: Int

    @inlinable
    init(_ base: S, separator: Character, maxSplits: Int) {
        self.base = base
        self.separator = separator
        self.maxSplits = maxSplits
    }

    @inlinable
    func makeIterator() -> Iterator {
        Iterator(base: self.base, separator: self.separator, maxSplits: self.maxSplits)
    }

    @usableFromInline
    struct Iterator: IteratorProtocol {
        @usableFromInline let base: S
        @usableFromInline let endIndex: S.Index
        @usableFromInline var currentIndex: S.Index
        @usableFromInline var availableSplits: Int
        @usableFromInline let separator: Character

        @inlinable
        init(base: S, separator: Character, maxSplits: Int) {
            self.base = base
            self.separator = separator
            self.endIndex = base.endIndex
            // Skip leading separator
            var index = base.startIndex
            while index < base.endIndex && base[index] == separator {
                base.formIndex(after: &index)
            }
            self.currentIndex = index
            self.availableSplits = maxSplits + 1
        }

        @inlinable
        mutating func next() -> S.SubSequence? {
            guard self.currentIndex < self.endIndex, self.availableSplits > 0 else { return nil }

            self.availableSplits -= 1
            if self.availableSplits == 0 {
                let component = base[self.currentIndex...]
                self.currentIndex = self.endIndex
                return component
            }

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

extension StringProtocol {
    @inlinable
    func splitSequence(separator: Character) -> SplitStringSequence<Self> {
        SplitStringSequence(self, separator: separator)
    }

    @inlinable
    func splitMaxSplitsSequence(separator: Character, maxSplits: Int) -> SplitStringMaxSplitsSequence<Self> {
        SplitStringMaxSplitsSequence(self, separator: separator, maxSplits: maxSplits)
    }
}
