import Foundation
import Hummingbird
import NIO
import NIOConcurrencyHelpers

public class DateCache {
    public var currentDate: String

    public init(eventLoop: EventLoop) {
        self.currentDate = Self.formatDate()
        eventLoop.scheduleRepeatedTask(initialDelay: .seconds(1), delay: .seconds(1)) { _ in
            self.updateDate()
        }
    }

    static func formatDate() -> String {
        return Self.rfc1123Formatter.string(from: Date())
    }

    func updateDate() {
        self.currentDate = Self.formatDate()
    }

    static var rfc1123Formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, d MMM yyy HH:mm:ss z"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}

extension HBApplication.EventLoopStorage {
    public var dateCache: DateCache {
        self.extensions.get(\._dateCache)!
    }

    fileprivate var _dateCache: DateCache? {
        get { self.extensions.get(\._dateCache) }
        set { self.extensions.set(\._dateCache, value: newValue) }
    }
}

extension HBApplication {
    func addDateCaches() {
        for eventLoop in eventLoopGroup.makeIterator() {
            let storage = self.eventLoopStorage(for: eventLoop)
            if storage._dateCache == nil {
                storage._dateCache = DateCache(eventLoop: eventLoop)
            }
        }
    }
}
