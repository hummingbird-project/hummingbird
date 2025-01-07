//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2017-2020 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if swift(>=6.0)

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension Date {
    init?(httpHeaderDate: String) {
        try? self.init(httpHeaderDate, strategy: .rfc9110)
    }

    var httpHeaderDate: String {
        self.formatted(.rfc9110)
    }
}

struct RFC9110DateParsingError: Error {}

struct RFC9110FormatStyle {

    let calendar: Calendar

    init() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        self.calendar = calendar
    }
}

extension RFC9110FormatStyle: ParseStrategy {
    func parse(_ input: String) throws -> Date {
        guard let components = self.components(from: input) else {
            throw RFC9110DateParsingError()
        }
        guard let date = components.date else {
            throw RFC9110DateParsingError()
        }
        return date
    }

    func components(from input: String) -> DateComponents? {
        var endIndex = input.endIndex
        // If the date string has a timezone in brackets, we need to remove it before parsing.
        if let bracket = input.firstIndex(of: "(") {
            endIndex = bracket
        }
        var s = input[input.startIndex..<endIndex]

        let asciiDigits = UInt8(ascii: "0")...UInt8(ascii: "9")

        return s.withUTF8 { buffer -> DateComponents? in
            func parseDay(_ it: inout UnsafeBufferPointer<UInt8>.Iterator) -> Int? {
                let first = it.next()
                let second = it.next()
                guard let first = first, let second = second else { return nil }

                guard asciiDigits.contains(first) else { return nil }

                let day: Int
                if asciiDigits.contains(second) {
                    day = Int(first - UInt8(ascii: "0")) * 10 + Int(second - UInt8(ascii: "0"))
                } else {
                    day = Int(first - UInt8(ascii: "0"))
                }

                guard self.calendar.maximumRange(of: .day)!.contains(day) else { return nil }

                return day
            }

            func parseMonth(_ it: inout UnsafeBufferPointer<UInt8>.Iterator) -> Int? {
                let first = it.nextAsciiLetter(skippingWhitespace: true)
                let second = it.nextAsciiLetter()
                let third = it.nextAsciiLetter()
                guard let first = first, let second = second, let third = third else { return nil }
                guard first.isAsciiLetter else { return nil }
                guard let month = monthMap[[first, second, third]] else { return nil }
                guard self.calendar.maximumRange(of: .month)!.contains(month) else { return nil }
                return month
            }

            func parseYear(_ it: inout UnsafeBufferPointer<UInt8>.Iterator) -> Int? {
                let first = it.nextAsciiDigit(skippingWhitespace: true)
                let second = it.nextAsciiDigit()
                let third = it.nextAsciiDigit()
                let fourth = it.nextAsciiDigit()
                guard let first = first,
                    let second = second,
                    let third = third,
                    let fourth = fourth
                else { return nil }
                return Int(first - UInt8(ascii: "0")) * 1000
                    + Int(second - UInt8(ascii: "0")) * 100
                    + Int(third - UInt8(ascii: "0")) * 10
                    + Int(fourth - UInt8(ascii: "0"))
            }

            func parseHour(_ it: inout UnsafeBufferPointer<UInt8>.Iterator) -> Int? {
                let first = it.nextAsciiDigit(skippingWhitespace: true)
                let second = it.nextAsciiDigit()
                guard let first = first, let second = second else { return nil }
                let hour = Int(first - UInt8(ascii: "0")) * 10 + Int(second - UInt8(ascii: "0"))
                guard self.calendar.maximumRange(of: .hour)!.contains(hour) else { return nil }
                return hour
            }

            func parseMinute(_ it: inout UnsafeBufferPointer<UInt8>.Iterator) -> Int? {
                let first = it.nextAsciiDigit(skippingWhitespace: true)
                let second = it.nextAsciiDigit()
                guard let first = first, let second = second else { return nil }
                let minute = Int(first - UInt8(ascii: "0")) * 10 + Int(second - UInt8(ascii: "0"))
                guard self.calendar.maximumRange(of: .minute)!.contains(minute) else { return nil }
                return minute
            }

            func parseSecond(_ it: inout UnsafeBufferPointer<UInt8>.Iterator) -> Int? {
                let first = it.nextAsciiDigit(skippingWhitespace: true)
                let second = it.nextAsciiDigit()
                guard let first = first, let second = second else { return nil }
                let value = Int(first - UInt8(ascii: "0")) * 10 + Int(second - UInt8(ascii: "0"))
                guard self.calendar.maximumRange(of: .second)!.contains(value) else { return nil }
                return value
            }

            func parseTimezone(_ it: inout UnsafeBufferPointer<UInt8>.Iterator) -> Int? {
                let plusMinus = it.nextSkippingWhitespace()
                if let plusMinus, plusMinus == UInt8(ascii: "+") || plusMinus == UInt8(ascii: "-") {
                    let hour = parseHour(&it)
                    let minute = parseMinute(&it)
                    guard let hour = hour, let minute = minute else { return nil }
                    return (hour * 60 + minute) * (plusMinus == UInt8(ascii: "+") ? 1 : -1)
                } else if let first = plusMinus {
                    let second = it.nextAsciiLetter()
                    let third = it.nextAsciiLetter()

                    guard let second = second, let third = third else { return nil }
                    let abbr = [first, second, third]
                    return timezoneOffsetMap[abbr]
                }

                return nil
            }

            var it = buffer.makeIterator()

            // if the 4th character is a comma, then we have a day of the week
            guard buffer.count > 5 else { return nil }

            if buffer[3] == UInt8(ascii: ",") {
                for _ in 0..<5 {
                    _ = it.next()
                }
            }

            guard let day = parseDay(&it) else { return nil }
            guard let month = parseMonth(&it) else { return nil }
            guard let year = parseYear(&it) else { return nil }

            guard let hour = parseHour(&it) else { return nil }
            guard it.expect(UInt8(ascii: ":")) else { return nil }
            guard let minute = parseMinute(&it) else { return nil }
            guard it.expect(UInt8(ascii: ":")) else { return nil }
            guard let second = parseSecond(&it) else { return nil }

            guard let timezoneOffsetMinutes = parseTimezone(&it) else { return nil }

            return DateComponents(
                calendar: self.calendar,
                timeZone: TimeZone(secondsFromGMT: timezoneOffsetMinutes * 60),
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute,
                second: second
            )
        }
    }
}

extension IteratorProtocol where Self.Element == UInt8 {
    mutating func expect(_ expected: UInt8) -> Bool {
        guard self.next() == expected else { return false }
        return true
    }

    mutating func nextSkippingWhitespace() -> UInt8? {
        while let c = self.next() {
            if c != UInt8(ascii: " ") {
                return c
            }
        }
        return nil
    }

    mutating func nextAsciiDigit(skippingWhitespace: Bool = false) -> UInt8? {
        while let c = self.next() {
            if skippingWhitespace {
                if c == UInt8(ascii: " ") {
                    continue
                }
            }
            switch c {
            case UInt8(ascii: "0")...UInt8(ascii: "9"): return c
            default: return nil
            }
        }
        return nil
    }

    mutating func nextAsciiLetter(skippingWhitespace: Bool = false) -> UInt8? {
        while let c = self.next() {
            if skippingWhitespace {
                if c == UInt8(ascii: " ") {
                    continue
                }
            }

            switch c {
            case UInt8(ascii: "A")...UInt8(ascii: "Z"),
                UInt8(ascii: "a")...UInt8(ascii: "z"):
                return c
            default: return nil
            }
        }
        return nil
    }
}

extension UInt8 {
    var isAsciiLetter: Bool {
        switch self {
        case UInt8(ascii: "A")...UInt8(ascii: "Z"),
            UInt8(ascii: "a")...UInt8(ascii: "z"):
            return true
        default: return false
        }
    }
}

let monthMap: [[UInt8]: Int] = [
    Array("Jan".utf8): 1,
    Array("Feb".utf8): 2,
    Array("Mar".utf8): 3,
    Array("Apr".utf8): 4,
    Array("May".utf8): 5,
    Array("Jun".utf8): 6,
    Array("Jul".utf8): 7,
    Array("Aug".utf8): 8,
    Array("Sep".utf8): 9,
    Array("Oct".utf8): 10,
    Array("Nov".utf8): 11,
    Array("Dec".utf8): 12,
]

let timezoneOffsetMap: [[UInt8]: Int] = [
    Array("UTC".utf8): 0,
    Array("GMT".utf8): 0,
    Array("EDT".utf8): -4 * 60,
    Array("CDT".utf8): -5 * 60,
    Array("MDT".utf8): -6 * 60,
    Array("PDT".utf8): -7 * 60,
]

extension RFC9110FormatStyle: FormatStyle {
    //let calendar: Calendar

    func format(_ value: Date) -> String {
        let components = calendar.dateComponents([.weekday, .day, .month, .year, .hour, .minute, .second], from: value)
        var formatted = Self.dayNames[components.weekday! - 1]
        formatted.reserveCapacity(30)
        formatted += ", "
        formatted += Self.numberNames[components.day!]
        formatted += " "
        formatted += Self.monthNames[components.month! - 1]
        formatted += " "
        formatted += "\(components.year!)"
        formatted += " "
        formatted += Self.numberNames[components.hour!]
        formatted += ":"
        formatted += Self.numberNames[components.minute!]
        formatted += ":"
        formatted += Self.numberNames[components.second!]
        formatted += " GMT"
        return formatted
    }
    private static let dayNames = [
        "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat",
    ]

    private static let monthNames = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ]

    private static let numberNames = [
        "00", "01", "02", "03", "04", "05", "06", "07", "08", "09",
        "10", "11", "12", "13", "14", "15", "16", "17", "18", "19",
        "20", "21", "22", "23", "24", "25", "26", "27", "28", "29",
        "30", "31", "32", "33", "34", "35", "36", "37", "38", "39",
        "40", "41", "42", "43", "44", "45", "46", "47", "48", "49",
        "50", "51", "52", "53", "54", "55", "56", "57", "58", "59",
        "60", "61", "62", "63", "64", "65", "66", "67", "68", "69",
        "70", "71", "72", "73", "74", "75", "76", "77", "78", "79",
        "80", "81", "82", "83", "84", "85", "86", "87", "88", "89",
        "90", "91", "92", "93", "94", "95", "96", "97", "98", "99",
    ]
}

extension FormatStyle where Self == RFC9110FormatStyle {
    static var rfc9110: Self { .init() }
}

extension ParseStrategy where Self == RFC9110FormatStyle {
    static var rfc9110: Self { .init() }
}

#else

import Foundation

extension Date {
    init?(httpHeaderDate: String) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyy HH:mm:ss z"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        guard let date = formatter.date(from: httpHeaderDate) else { return nil }
        self = date
    }

    var httpHeaderDate: String {
        var epochTime = Int(self.timeIntervalSince1970)
        var timeStruct = tm.init()
        gmtime_r(&epochTime, &timeStruct)
        let year = Int(timeStruct.tm_year + 1900)
        let day = Self.dayNames[numericCast(timeStruct.tm_wday)]
        let month = Self.monthNames[numericCast(timeStruct.tm_mon)]
        var formatted = day
        formatted.reserveCapacity(30)
        formatted += ", "
        formatted += Self.numberNames[numericCast(timeStruct.tm_mday)]
        formatted += " "
        formatted += month
        formatted += " "
        formatted += Self.numberNames[year / 100]
        formatted += Self.numberNames[year % 100]
        formatted += " "
        formatted += Self.numberNames[numericCast(timeStruct.tm_hour)]
        formatted += ":"
        formatted += Self.numberNames[numericCast(timeStruct.tm_min)]
        formatted += ":"
        formatted += Self.numberNames[numericCast(timeStruct.tm_sec)]
        formatted += " GMT"

        return formatted
    }

    private static let dayNames = [
        "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat",
    ]

    private static let monthNames = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ]

    private static let numberNames = [
        "00", "01", "02", "03", "04", "05", "06", "07", "08", "09",
        "10", "11", "12", "13", "14", "15", "16", "17", "18", "19",
        "20", "21", "22", "23", "24", "25", "26", "27", "28", "29",
        "30", "31", "32", "33", "34", "35", "36", "37", "38", "39",
        "40", "41", "42", "43", "44", "45", "46", "47", "48", "49",
        "50", "51", "52", "53", "54", "55", "56", "57", "58", "59",
        "60", "61", "62", "63", "64", "65", "66", "67", "68", "69",
        "70", "71", "72", "73", "74", "75", "76", "77", "78", "79",
        "80", "81", "82", "83", "84", "85", "86", "87", "88", "89",
        "90", "91", "92", "93", "94", "95", "96", "97", "98", "99",
    ]
}

#endif  // #if swift(>=6.0)
