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

import HummingbirdCore
import Logging

/// Extend objects with additional member variables
///
/// If you have only one instance of a type to attach you can extend it to conform to `StorageKey`
/// ```
/// struct Object {
///     var extensions: Extensions<Object>
/// }
///
/// extension Object {
///     var extra: Extra? {
///         get { return extensions.get(\.extra) }
///         set { extensions.set(\.extra, value: newValue) }
///     }
/// }
/// ```
public struct HBExtensions<ParentObject> {
    /// Initialize extensions
    public init() {
        self.items = [:]
    }

    /// Get optional extension from a `KeyPath`
    @inlinable
    public func get<Type>(_ key: KeyPath<ParentObject, Type>) -> Type? {
        self.items[key.hashValue]?.value as? Type
    }

    /// Get extension from a `KeyPath`
    @inlinable
    public func get<Type>(_ key: KeyPath<ParentObject, Type>, error: StaticString? = nil) -> Type {
        guard let value = items[key.hashValue]?.value as? Type else {
            preconditionFailure(error?.description ?? "Cannot get extension of type \(Type.self) without having set it")
        }
        return value
    }

    /// Return if extension has been set
    @inlinable
    public func exists<Type>(_ key: KeyPath<ParentObject, Type>) -> Bool {
        self.items[key.hashValue]?.value != nil
    }

    /// Set extension for a `KeyPath`
    /// - Parameters:
    ///   - key: KeyPath
    ///   - value: value to store in extension
    ///   - shutdownCallback: closure to call when extensions are shutsdown
    @inlinable
    public mutating func set<Type>(_ key: KeyPath<ParentObject, Type>, value: Type, shutdownCallback: ((Type) throws -> Void)? = nil) {
        let keyHash = key.hashValue
        if let item = items[keyHash] {
            guard item.shutdown == nil else {
                preconditionFailure("Cannot replace items with shutdown functions")
            }
        }
        self.items[keyHash] = .init(
            value: value,
            shutdown: shutdownCallback.map { callback in
                return { item in try callback(item as! Type) }
            }
        )
    }

    mutating func shutdown() throws {
        for item in self.items.values {
            try item.shutdown?(item.value)
        }
        self.items = [:]
    }

    @usableFromInline
    struct Item {
        @usableFromInline
        init(value: Any, shutdown: ((Any) throws -> Void)? = nil) {
            self.value = value
            self.shutdown = shutdown
        }

        @usableFromInline
        let value: Any
        @usableFromInline
        let shutdown: ((Any) throws -> Void)?
    }

    @usableFromInline
    var items: [Int: Item]
}

/// Protocol for extensible classes
public protocol HBExtensible {
    @inlinable
    var extensions: HBExtensions<Self> { get set }
}

/// Version of `HBExtensions` that requires all extensions are sendable
public struct HBSendableExtensions<ParentObject>: Sendable {
    /// Initialize extensions
    @inlinable
    public init() {
        self.items = [:]
    }

    /// Get optional extension from a `KeyPath`
    @inlinable
    public func get<Type: HBSendable>(_ key: KeyPath<ParentObject, Type>) -> Type? {
        self.items[key.hashValue]?.value as? Type
    }

    /// Get extension from a `KeyPath`
    @inlinable
    public func get<Type: HBSendable>(_ key: KeyPath<ParentObject, Type>, error: StaticString? = nil) -> Type {
        guard let value = items[key.hashValue]?.value as? Type else {
            preconditionFailure(error?.description ?? "Cannot get extension of type \(Type.self) without having set it")
        }
        return value
    }

    /// Return if extension has been set
    @inlinable
    public func exists<Type: HBSendable>(_ key: KeyPath<ParentObject, Type>) -> Bool {
        self.items[key.hashValue]?.value != nil
    }

    /// Set extension for a `KeyPath`
    /// - Parameters:
    ///   - key: KeyPath
    ///   - value: value to store in extension
    ///   - shutdownCallback: closure to call when extensions are shutsdown
    @inlinable
    public mutating func set<Type: HBSendable>(_ key: KeyPath<ParentObject, Type>, value: Type) {
        self.items[key.hashValue] = .init(
            value: value
        )
    }

    @usableFromInline
    struct Item: Sendable {
        @usableFromInline
        internal init(value: Sendable) {
            self.value = value
        }

        @usableFromInline
        let value: Sendable
    }

    @usableFromInline
    var items: [Int: Item]
}

/// Protocol for extensible classes
public protocol HBSendableExtensible {
    @inlinable
    var extensions: HBSendableExtensions<Self> { get set }
}
