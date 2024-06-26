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

    /// ISO8601 data formatter used throughout URL encoded form code
    static var iso8601Formatter: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = .withInternetDateTime
        return formatter
    }
}
