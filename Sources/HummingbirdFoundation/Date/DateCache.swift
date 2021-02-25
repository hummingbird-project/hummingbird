import Foundation
import Hummingbird
import NIO

/// Current date cache.
///
/// Getting the current date formatted is an expensive operation. This creates a scheduled task that will
/// update a cached version of the date in the format as detailed in RFC1123 once every second. To
/// avoid threading issues it is assumed that `currentDate` will only every be accessed on the same
/// EventLoop that the update is running.
public class HBDateCache {
    /// Current formatted date
    public var currentDate: String

    /// Initialize DateCache to run on a specific `EventLoop`
    /// - Parameter eventLoop: <#eventLoop description#>
    public init(eventLoop: EventLoop) {
        self.currentDate = Self.formatDate()
        let millisecondsSinceLastSecond = Date().timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.0) * 1000
        let millisecondsUntilNextSecond = Int64(1000.0 - millisecondsSinceLastSecond)
        eventLoop.scheduleRepeatedTask(initialDelay: .milliseconds(millisecondsUntilNextSecond), delay: .seconds(1)) { _ in
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
    /// Add `DateCache` to every `EventLoop`
    public var dateCache: HBDateCache {
        self.extensions.get(\._dateCache)!
    }

    fileprivate var _dateCache: HBDateCache? {
        get { self.extensions.get(\._dateCache) }
        set { self.extensions.set(\._dateCache, value: newValue) }
    }
}

extension HBApplication {
    /// Add a `DateCache` for every `EventLoop` in the `EventLoopGroup` associated with the application
    func addDateCaches() {
        for eventLoop in eventLoopGroup.makeIterator() {
            let storage = self.eventLoopStorage(for: eventLoop)
            if storage._dateCache == nil {
                storage._dateCache = HBDateCache(eventLoop: eventLoop)
            }
        }
    }
}
