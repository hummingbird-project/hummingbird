import NIO

/// Allow user to attach data to EventLoop.
///
/// Extend EventLoopStorage using HBExtensions.
/// Access data via `request.eventLoopStorage`
extension HBApplication {
    public class EventLoopStorage {
        public var extensions: HBExtensions<EventLoopStorage>
        init() {
            self.extensions = .init()
        }
    }

    public struct EventLoopStorageMap {
        init(eventLoopGroup: EventLoopGroup) {
            var eventLoops: [EventLoop.Key: EventLoopStorage] = [:]
            for eventLoop in eventLoopGroup.makeIterator() {
                eventLoops[eventLoop.key] = .init()
            }
            self.eventLoops = eventLoops
            self.eventLoopGroup = eventLoopGroup
        }

        public func get(for eventLoop: EventLoop) -> EventLoopStorage {
            guard let storage = eventLoops[eventLoop.key] else {
                preconditionFailure("EventLoop must be from the Application's EventLoopGroup")
            }
            return storage
        }

        fileprivate let eventLoopGroup: EventLoopGroup
        fileprivate let eventLoops: [EventLoop.Key: EventLoopStorage]
    }

    public var eventLoopStorage: EventLoopStorageMap {
        get { return extensions.get(\.eventLoopStorage) }
        set { return extensions.set(\.eventLoopStorage, value: newValue) }
    }

    public func eventLoopStorage(for eventLoop: EventLoop) -> EventLoopStorage {
        return self.eventLoopStorage.get(for: eventLoop)
    }

    /// Allow the application to attach data to each EventLoop
    public func addEventLoopStorage() {
        self.eventLoopStorage = .init(eventLoopGroup: self.eventLoopGroup)
    }
}

extension HBRequest {
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
