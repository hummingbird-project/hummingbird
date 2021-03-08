import NIO

/// Allow user to attach data to EventLoop.
///
/// Access data via `request.eventLoopStorage`.
extension HBApplication {
    // MARK: EventLoopStorage

    /// Extend EventLoopStorage using HBExtensions.
    ///
    /// Use this to add additional data to each `EventLoop` in the application `EventLoopGroup`.
    /// ```
    /// extension HBApplication.EventLoopStorage {
    ///     var myVar: String {
    ///         get { extensions.get(\.myVar) }
    ///         set { extensions.set(\.myVar, value: newValue) }
    ///     }
    /// }
    /// ```
    /// You can access the extension via `HBApplication.eventLoopStorage(for: eventLoop).myVar` or
    /// if you have an `HBRequest` you can access the extension via `HBRequest.eventLoopStorage.myVar`.
    public class EventLoopStorage {
        /// Allows you tp extend `EventLoopStorage`
        public var extensions: HBExtensions<EventLoopStorage>
        init() {
            self.extensions = .init()
        }
    }

    /// Provide access to `EventLoopStorage` from `EventLoop`.
    public struct EventLoopStorageMap {
        init(eventLoopGroup: EventLoopGroup) {
            var eventLoops: [EventLoop.Key: EventLoopStorage] = [:]
            for eventLoop in eventLoopGroup.makeIterator() {
                eventLoops[eventLoop.key] = .init()
            }
            self.eventLoops = eventLoops
            self.eventLoopGroup = eventLoopGroup
        }

        /// get `EventLoopStorage` from `EventLoop`
        public func get(for eventLoop: EventLoop) -> EventLoopStorage {
            let storage = eventLoops[eventLoop.key]
            assert(storage != nil, "EventLoop must be from the Application's EventLoopGroup")
            return storage!
        }

        fileprivate let eventLoopGroup: EventLoopGroup
        fileprivate let eventLoops: [EventLoop.Key: EventLoopStorage]
    }

    /// EventLoopStorageMap for Application.
    public private(set) var eventLoopStorage: EventLoopStorageMap {
        get { return extensions.get(\.eventLoopStorage) }
        set { return extensions.set(\.eventLoopStorage, value: newValue) }
    }

    /// Get `EventLoopStorage` for `EventLoop`
    public func eventLoopStorage(for eventLoop: EventLoop) -> EventLoopStorage {
        return self.eventLoopStorage.get(for: eventLoop)
    }

    /// Allow the application to attach data to each EventLoop
    public func addEventLoopStorage() {
        self.eventLoopStorage = .init(eventLoopGroup: self.eventLoopGroup)
    }
}

extension HBRequest {
    // MARK: EventLoopStorage

    /// Access extension data associated with the `EventLoop` used by this Request
    public var eventLoopStorage: HBApplication.EventLoopStorage {
        self.application.eventLoopStorage(for: self.eventLoop)
    }
}

private extension EventLoop {
    typealias Key = ObjectIdentifier
    var key: Key {
        ObjectIdentifier(self)
    }
}

/// extend EventLoopStorageMap to be a Sequence
extension HBApplication.EventLoopStorageMap: Sequence {
    /// EventLoopStorageMap iterator
    public struct Iterator: Sequence, IteratorProtocol {
        public typealias Element = (eventLoop: EventLoop, storage: HBApplication.EventLoopStorage)

        private var eventLoopStorage: HBApplication.EventLoopStorageMap
        private var iterator: EventLoopIterator

        /// Create an `Iterator` from an array of `EventLoop`s.
        public init(_ eventLoopStorage: HBApplication.EventLoopStorageMap) {
            self.eventLoopStorage = eventLoopStorage
            self.iterator = eventLoopStorage.eventLoopGroup.makeIterator()
        }

        /// Advances to the next `EventLoop` and returns it, or `nil` if no next element exists.
        ///
        /// - returns: The next `EventLoop` if a next element exists; otherwise, `nil`.
        public mutating func next() -> Element? {
            guard let eventLoop = self.iterator.next() else { return nil }
            return (eventLoop: eventLoop, storage: self.eventLoopStorage.get(for: eventLoop))
        }
    }

    public typealias Element = Iterator.Element

    public func makeIterator() -> HBApplication.EventLoopStorageMap.Iterator {
        return Iterator(self)
    }
}
