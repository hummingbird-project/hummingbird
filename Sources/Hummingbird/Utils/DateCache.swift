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

import AsyncAlgorithms
import Atomics
import NIOCore
import NIOPosix
#if os(Linux)
import Glibc
#else
import Darwin.C
#endif
import ServiceLifecycle

/// Current date formatted cache service
///
/// Getting the current date formatted is an expensive operation. This creates a task that will
/// update a cached version of the date in the format as detailed in RFC1123 once every second.
public final class HBDateCache: Service {
    final class DateContainer: AtomicReference, Sendable {
        let date: String

        init(date: String) {
            self.date = date
        }
    }

    let dateContainer: ManagedAtomic<DateContainer>

    init() {
        let epochTime = time(nil)
        self.dateContainer = .init(.init(date: Self.formatRFC1123Date(epochTime)))
    }

    public func run() async throws {
        let cancelled = ManagedAtomic(false)
        if #available(macOS 13.0, *) {
            let timerSequence = AsyncTimerSequence(interval: .seconds(1), clock: .suspending)
                .cancelOnGracefulShutdown()
            for try await _ in timerSequence {
                let epochTime = time(nil)
                self.dateContainer.store(.init(date: Self.formatRFC1123Date(epochTime)), ordering: .relaxed)
            }
        } else {
            try await withGracefulShutdownHandler {
                while !cancelled.load(ordering: .relaxed) {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    let epochTime = time(nil)
                    self.dateContainer.store(.init(date: Self.formatRFC1123Date(epochTime)), ordering: .relaxed)
                }
            } onGracefulShutdown: {
                cancelled.store(true, ordering: .relaxed)
            }
        }
    }

    public var date: String {
        return self.dateContainer.load(ordering: .relaxed).date
    }

    /// Render Epoch seconds as RFC1123 formatted date
    /// - Parameter epochTime: epoch seconds to render
    /// - Returns: Formatted date
    public static func formatRFC1123Date(_ epochTime: Int) -> String {
        var epochTime = epochTime
        var timeStruct = tm.init()
        gmtime_r(&epochTime, &timeStruct)
        let year = Int(timeStruct.tm_year + 1900)
        let day = self.dayNames[numericCast(timeStruct.tm_wday)]
        let month = self.monthNames[numericCast(timeStruct.tm_mon)]
        var formatted = day
        formatted.reserveCapacity(30)
        formatted += ", "
        formatted += timeStruct.tm_mday.description
        formatted += " "
        formatted += month
        formatted += " "
        formatted += self.numberNames[year / 100]
        formatted += self.numberNames[year % 100]
        formatted += " "
        formatted += self.numberNames[numericCast(timeStruct.tm_hour)]
        formatted += ":"
        formatted += self.numberNames[numericCast(timeStruct.tm_min)]
        formatted += ":"
        formatted += self.numberNames[numericCast(timeStruct.tm_sec)]
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
