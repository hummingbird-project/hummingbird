/// Extend objects with additional member variables
///
/// If you have only one instance of a type to attach you can extend it to conform to `StorageKey`
/// ```
/// struct Object {
///     var storage: Storage<Object>
/// }
///
/// extension Object {
///     var extra: Extra? {
///         get { return storage.get(\.extra) }
///         set { storage.set(\.extra, value: newValue) }
///     }
/// }
/// ```
public struct Storage<ParentObject> {
    public init() {
        self.items = [:]
    }

    public func get<Type>(_ key: KeyPath<ParentObject, Type>) -> Type? {
        items[key] as? Type
    }

    public func get<Type>(_ key: KeyPath<ParentObject, Type>) -> Type {
        items[key] as! Type
    }

    public mutating func set<Type>(_ key: KeyPath<ParentObject, Type>, value: Type?) {
        items[key] = value
    }

    var items: [PartialKeyPath<ParentObject>: Any]
}
