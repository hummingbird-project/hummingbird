//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import HummingbirdTesting
import Testing

@testable import Hummingbird

extension HTTPTests {
    struct HeaderDateTests {
        @Test func testHTTPHeaderDateRenderer() {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "EEE, dd MMM yyy HH:mm:ss z"
            formatter.timeZone = TimeZone(secondsFromGMT: 0)

            for _ in 0..<1000 {
                let time = Int.random(in: 1...4 * Int(Int32.max))
                let date = Date(timeIntervalSince1970: Double(time))
                #expect(
                    formatter.string(from: date) == date.httpHeader
                )
            }
        }

        @Test func testDateHeader() async throws {
            let router = Router()
            router.get("date") { _, _ in
                "hello"
            }
            let app = Application(responder: router.buildResponder())

            try await app.test(.live) { client in
                let date = try await client.execute(uri: "/date", method: .get) { response in
                    #expect(response.headers[.date] != nil)
                    return response.headers[.date]
                }
                try await Task.sleep(nanoseconds: 1_500_000_000)
                try await client.execute(uri: "/date", method: .get) { response in
                    #expect(response.headers[.date] != date)
                }
            }
        }

        /// convert from date to string and back
        @Test func testFormatStyleAndParser() throws {
            for _ in 0..<1000 {
                let time = Int.random(in: 1...4 * Int(Int32.max))
                let date = Date(timeIntervalSince1970: Double(time))
                let string = date.httpHeader
                let parsedDate = Date(httpHeader: string)
                #expect(date == parsedDate)
            }
        }

        /// convert from string to date and back
        @Test func testParserAndFormatStyle() throws {
            func checkDates(_ dates: [(String, String)]) throws {
                for entry in dates {
                    let date = try #require(Date(httpHeader: entry.0))
                    let string = date.httpHeader
                    #expect(string == entry.1)
                }
            }
            let dates = [
                ("Sat, 15 Feb 2020 01:02:03 GMT", "Sat, 15 Feb 2020 01:02:03 GMT"),
                ("Mon, 15 Jun 2020 13:32:47 GMT", "Mon, 15 Jun 2020 13:32:47 GMT"),
                ("Mon, 30 Mar 2020 02:03:04 UTC", "Mon, 30 Mar 2020 02:03:04 GMT"),
                ("Wed, 01 Jan 2020 00:00:00 +0000", "Wed, 01 Jan 2020 00:00:00 GMT"),
                ("Wed, 15 Apr 2020 03:04:05 -0500", "Wed, 15 Apr 2020 08:04:05 GMT"),
            ]
            try checkDates(dates)

            let dates2 = [
                ("Mon, 1 Jun 2020 04:05:06 -0600 (EDT)", "Mon, 01 Jun 2020 10:05:06 GMT"),
                ("30 Oct 2020 08:09:10 -1000", "Fri, 30 Oct 2020 18:09:10 GMT"),
                ("Sun, 15 Nov 2020 09:10:11 -1100 (AKST)", "Sun, 15 Nov 2020 20:10:11 GMT"),
                ("30 Dec 2020 10:11:12 -1200 (HST)", "Wed, 30 Dec 2020 22:11:12 GMT"),
            ]
            try checkDates(dates2)
        }
    }
}
