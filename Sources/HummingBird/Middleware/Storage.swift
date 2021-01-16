/// Protocol for objects that can be used as a Key in the Storage object
public protocol StorageKey {
    associatedtype Value = Self
}

/// Extend objects with additional member variables
///
/// If you have only one instance of a type to attach you can extend it to conform to `StorageKey`
/// ```
/// struct Object {
///     var storage: Storage
/// }
///
/// extension Extra: StorageKey {}
/// extension Object {
///     var extra: Extra? {
///         get { return storage.get(Extra.self) }
///         set { storage.set(Extra.self, value: newValue) }
///     }
/// }
/// ```
/// If you are planning to include multiple copies of a type in one object then create new types for your `StorageKey`
/// ```
/// extension Object {
///     struct ExtraKey1: StorageKey {
///         typealias Value = Extra
///     }
///     struct ExtraKey2: StorageKey {
///         typealias Value = Extra
///     }
///     var extra1: Extra? {
///         get { return storage.get(ExtraKey1.self) }
///         set { storage.set(ExtraKey1.self, value: newValue) }
///     }
///     var extra2: Extra? {
///         get { return storage.get(ExtraKey2.self) }
///         set { storage.set(ExtraKey2.self, value: newValue) }
///     }
/// }
/// ```
public struct Storage {
    public init() {
        self.items = [:]
    }

    public func get<Key: StorageKey>(_ key: Key.Type) -> Key.Value? {
        items[ObjectIdentifier(key)] as? Key.Value
    }

    public mutating func set<Key: StorageKey>(_ key: Key.Type, value: Key.Value?) {
        items[ObjectIdentifier(key)] = value
    }

    var items: [ObjectIdentifier: Any]
}

public struct Storage2<Parent> {
    public init() {
        self.items = [:]
    }

    public func get<Type>(_ key: KeyPath<Parent, Type>) -> Type? {
        items[key] as? Type
    }

    public mutating func set<Type>(_ key: KeyPath<Parent, Type>, value: Type?) {
        items[key] = value
    }

    var items: [PartialKeyPath<Parent>: Any]
}

