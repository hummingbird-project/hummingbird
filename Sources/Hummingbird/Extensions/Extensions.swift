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
    public func get<Type>(_ key: KeyPath<ParentObject, Type>) -> Type? {
        self.items[key]?.value as? Type
    }

    /// Get extension from a `KeyPath`
    public func get<Type>(_ key: KeyPath<ParentObject, Type>, error: StaticString? = nil) -> Type {
        guard let value = items[key]?.value as? Type else {
            preconditionFailure(error?.description ?? "Cannot get extension of type \(Type.self) without having set it")
        }
        return value
    }

    /// Return if extension has been set
    public func exists<Type>(_ key: KeyPath<ParentObject, Type>) -> Bool {
        self.items[key]?.value != nil
    }

    /// Set extension for a `KeyPath`
    /// - Parameters:
    ///   - key: KeyPath
    ///   - value: value to store in extension
    ///   - shutdownCallback: closure to call when extensions are shutsdown
    public mutating func set<Type>(_ key: KeyPath<ParentObject, Type>, value: Type, shutdownCallback: ((Type) throws -> Void)? = nil) {
        if let item = items[key] {
            guard item.shutdown == nil else {
                preconditionFailure("Cannot replace items with shutdown functions")
            }
        }
        self.items[key] = .init(
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

    struct Item {
        let value: Any
        let shutdown: ((Any) throws -> Void)?
    }

    var items: [PartialKeyPath<ParentObject>: Item]
}

/// Protocol for extensible classes
public protocol HBExtensible {
    var extensions: HBExtensions<Self> { get set }
}

/// Version of `HBExtensions` that requires all extensions are sendable
public struct HBSendableExtensions<ParentObject> {
    /// Initialize extensions
    public init() {
        self.items = [:]
    }

    /// Get optional extension from a `KeyPath`
    public func get<Type: HBSendable>(_ key: KeyPath<ParentObject, Type>) -> Type? {
        self.items[key]?.value as? Type
    }

    /// Get extension from a `KeyPath`
    public func get<Type: HBSendable>(_ key: KeyPath<ParentObject, Type>, error: StaticString? = nil) -> Type {
        guard let value = items[key]?.value as? Type else {
            preconditionFailure(error?.description ?? "Cannot get extension of type \(Type.self) without having set it")
        }
        return value
    }

    /// Return if extension has been set
    public func exists<Type: HBSendable>(_ key: KeyPath<ParentObject, Type>) -> Bool {
        self.items[key]?.value != nil
    }

    /// Set extension for a `KeyPath`
    /// - Parameters:
    ///   - key: KeyPath
    ///   - value: value to store in extension
    ///   - shutdownCallback: closure to call when extensions are shutsdown
    public mutating func set<Type: HBSendable>(_ key: KeyPath<ParentObject, Type>, value: Type) {
        self.items[key] = .init(
            value: value
        )
    }

    struct Item {
        let value: Any
    }

    var items: [PartialKeyPath<ParentObject>: Item]
}

/// Protocol for extensible classes
public protocol HBSendableExtensible {
    var extensions: HBSendableExtensions<Self> { get set }
}

#if compiler(>=5.6)
/// Conform to @unchecked Sendable as the PartialKeyPath in the item dictionary is not Sendable
extension HBSendableExtensions: @unchecked Sendable {}
#endif
