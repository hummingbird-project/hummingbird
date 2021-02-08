import Foundation

internal enum URLEncodedForm {
    /// CodingKey used by URLEncodedFormEncoder and URLEncodedFormDecoder
    struct Key: CodingKey {
        var stringValue: String
        var intValue: Int?

        init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }

        init?(intValue: Int) {
            self.stringValue = "\(intValue)"
            self.intValue = intValue
        }

        init(stringValue: String, intValue: Int?) {
            self.stringValue = stringValue
            self.intValue = intValue
        }

        init(index: Int) {
            self.stringValue = "\(index)"
            self.intValue = index
        }

        fileprivate static let `super` = Key(stringValue: "super")!
    }

    /// ASCII characters that will not be percent encoded in URL encoded form data
    static let unreservedCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~")

    @available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
    /// ISO8601 data formatter used throughout URL encoded form code
    static var iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = .withInternetDateTime
        return formatter
    }()
}
