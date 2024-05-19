//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2022 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// Provides Dictionary like indexing, but uses a flat array of key
/// value pairs, plus an array of hash keys for lookup for storage.
///
/// Useful for dictionary lookup on small collection that don't need
/// a tree lookup to optimise indexing.
///
/// The FlatDictionary also allows for key clashes. Standard lookup
/// functions will always return the first key found, but if you
/// iterate through the key,value pairs you can access all values
/// for a key
public struct FlatDictionary<Key: Hashable, Value>: Collection, ExpressibleByDictionaryLiteral {
    public typealias Element = (key: Key, value: Value)
    public typealias Index = Array<Element>.Index

    @usableFromInline
    struct Storage {
        @usableFromInline internal /* private */ var elements: [Element]
        @usableFromInline internal /* private */ var hashKeys: [Int]

        @usableFromInline
        init(elements: [Element], hashKeys: [Int]) {
            self.elements = elements
            self.hashKeys = hashKeys
        }
    }

    @usableFromInline internal /* private */ var storage: Storage?

    // MARK: Collection requirements

    /// The position of the first element
    @inlinable
    public var startIndex: Index { self.storage?.elements.startIndex ?? 0 }
    /// The position of the element just after the last element
    @inlinable
    public var endIndex: Index { self.storage?.elements.endIndex ?? 0 }
    /// Access element at specific position
    @inlinable
    public subscript(_ index: Index) -> Element { return self.storage!.elements[index] }
    /// Returns the index immediately after the given index
    @inlinable
    public func index(after index: Index) -> Index { index + 1 }

    /// Create a new FlatDictionary
    @inlinable
    public init() {}

    /// Create a new FlatDictionary initialized with a dictionary literal
    public init(dictionaryLiteral elements: (Key, Value)...) {
        self.storage = Storage(
            elements: elements.map { (key: $0.0, value: $0.1) },
            hashKeys: elements.map {
                Self.hashKey($0.0)
            }
        )
    }

    /// Create a new FlatDictionary from an array of key value pairs
    public init(_ values: [Element]) {
        self.storage = Storage(
            elements: values,
            hashKeys: values.map {
                Self.hashKey($0.0)
            }
        )
    }

    /// Access the value associated with a given key for reading and writing
    ///
    /// Because FlatDictionary allows for key clashes this function will
    /// return the first entry in the array with the associated key
    @inlinable
    public subscript(_ key: Key) -> Value? {
        get {
            let hashKey = Self.hashKey(key)
            if let storage, let index = storage.hashKeys.firstIndex(of: hashKey) {
                return storage.elements[index].value
            } else {
                return nil
            }
        }
        set {
            let hashKey = Self.hashKey(key)
            if var storage, let index = storage.hashKeys.firstIndex(of: hashKey) {
                if let newValue {
                    storage.elements[index].value = newValue
                } else {
                    storage.elements.remove(at: index)
                    storage.hashKeys.remove(at: index)
                }

                self.storage = storage
            } else if let newValue {
                if var storage {
                    storage.elements.append((key: key, value: newValue))
                    storage.hashKeys.append(hashKey)
                    self.storage = storage
                } else {
                    self.storage = Storage(
                        elements: [(key: key, value: newValue)],
                        hashKeys: [hashKey]
                    )
                }
            }
        }
    }

    /// Return all the values, associated with a given key
    @inlinable
    public subscript(values key: Key) -> [Value] {
        guard let storage else {
            return []
        }

        var values: [Value] = []
        let hashKey = Self.hashKey(key)

        for hashIndex in 0..<storage.hashKeys.count {
            if storage.hashKeys[hashIndex] == hashKey {
                values.append(storage.elements[hashIndex].value)
            }
        }
        return values
    }

    ///  Return if dictionary has this value
    /// - Parameter key:
    @inlinable
    public func has(_ key: Key) -> Bool {
        guard let storage else {
            return false
        }

        let hashKey = Self.hashKey(key)
        return storage.hashKeys.firstIndex(of: hashKey) != nil
    }

    /// Append a new key value pair to the list of key value pairs
    @inlinable
    public mutating func append(key: Key, value: Value) {
        let hashKey = Self.hashKey(key)

        if var storage {
            storage.elements.append((key: key, value: value))
            storage.hashKeys.append(hashKey)
            self.storage = storage
        } else {
            self.storage = Storage(
                elements: [(key: key, value: value)],
                hashKeys: [hashKey]
            )
        }
    }

    @usableFromInline
    internal /* private */ static func hashKey(_ key: Key) -> Int {
        var hasher = Hasher()
        hasher.combine(key)
        return hasher.finalize()
    }
}

// FlatDictionary is Sendable when Key and Value are Sendable
extension FlatDictionary: Sendable where Key: Sendable, Value: Sendable {}
