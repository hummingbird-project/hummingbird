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

    struct EventLoopStorageMap {
        init(eventLoopGroup: EventLoopGroup) {
            var eventLoops: [EventLoop.Key: EventLoopStorage] = [:]
            for eventLoop in eventLoopGroup.makeIterator() {
                eventLoops[eventLoop.key] = .init()
            }
            self.eventLoops = eventLoops
        }

        func get(for eventLoop: EventLoop) -> EventLoopStorage {
            guard let storage = eventLoops[eventLoop.key] else {
                preconditionFailure("EventLoop must be from the Application's EventLoopGroup")
            }
            return storage
        }

        fileprivate let eventLoops: [EventLoop.Key: EventLoopStorage]
    }

    var eventLoopStorage: EventLoopStorageMap {
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
