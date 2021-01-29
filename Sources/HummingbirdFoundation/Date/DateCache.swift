import Foundation
import Hummingbird
import NIO
import NIOConcurrencyHelpers

public class DateCache {
    var _currentDate: String
    var currentDateSeconds: Int

    public init() {
        self.currentDateSeconds = Int(Date().timeIntervalSince1970.rounded(.down))
        self._currentDate = Self.formatDate()
    }

    public var currentDate: String {
        let date = Int(Date().timeIntervalSince1970.rounded(.down))
        if date == currentDateSeconds {
            return _currentDate
        } else {
            updateDate()
            return _currentDate
        }
    }

    static func formatDate() -> String {
        return Self.dateFormatter.string(from: Date())
    }

    func updateDate() {
        self._currentDate = Self.formatDate()
    }

    static var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, d MMM yyy HH:mm:ss z"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}

extension HBApplication.EventLoopStorage {
    public var dateCache: DateCache {
        get { self.extensions.get(\.dateCache) }
        set { self.extensions.set(\.dateCache, value: newValue) }
    }
}
