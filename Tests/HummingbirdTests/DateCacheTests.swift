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
import HummingbirdTesting
import XCTest

@testable import Hummingbird

final class DateTests: XCTestCase {
    func testHTTPHeaderDateRenderer() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyy HH:mm:ss z"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        for _ in 0..<1000 {
            let time = Int.random(in: 1...4 * Int(Int32.max))
            let date = Date(timeIntervalSince1970: Double(time))
            XCTAssertEqual(
                formatter.string(from: date),
                date.httpHeader
            )
        }
    }

    func testDateHeader() async throws {
        let router = Router()
        router.get("date") { _, _ in
            "hello"
        }
        let app = Application(responder: router.buildResponder())

        try await app.test(.live) { client in
            let date = try await client.execute(uri: "/date", method: .get) { response in
                XCTAssertNotNil(response.headers[.date])
                return response.headers[.date]
            }
            try await Task.sleep(nanoseconds: 1_500_000_000)
            try await client.execute(uri: "/date", method: .get) { response in
                XCTAssertNotEqual(response.headers[.date], date)
            }
        }
    }

    /// convert from date to string and back
    func testFormatStyleAndParser() throws {
        for _ in 0..<1000 {
            let time = Int.random(in: 1...4 * Int(Int32.max))
            let date = Date(timeIntervalSince1970: Double(time))
            let string = date.httpHeader
            let parsedDate = Date(httpHeader: string)
            XCTAssertEqual(date, parsedDate)
        }
    }

    /// convert from string to date and back
    func testParserAndFormatStyle() throws {
        let dates = [
            ("15 Feb 2020 01:02:03 GMT", "Sat, 15 Feb 2020 01:02:03 GMT"),
            ("15 Jun 2020 13:32:47 GMT", "Mon, 15 Jun 2020 13:32:47 GMT"),
            ("30 Mar 2020 02:03:04 UTC", "Mon, 30 Mar 2020 02:03:04 GMT"),
            ("Wed, 01 Jan 2020 00:00:00 +0000", "Wed, 01 Jan 2020 00:00:00 GMT"),
            ("15 Apr 2020 03:04:05 -0500 (CDT)", "Wed, 15 Apr 2020 08:04:05 GMT"),
            ("1 Jun 2020 04:05:06 -0600 (EDT)", "Mon, 01 Jun 2020 10:05:06 GMT"),
            ("30 Oct 2020 08:09:10 -1000", "Fri, 30 Oct 2020 18:09:10 GMT"),
            ("Sun, 15 Nov 2020 09:10:11 -1100 (AKST)", "Sun, 15 Nov 2020 20:10:11 GMT"),
            ("30 Dec 2020 10:11:12 -1200 (HST)", "Wed, 30 Dec 2020 22:11:12 GMT"),
        ]
        for entry in dates {
            guard let date = Date(httpHeader: entry.0) else {
                XCTFail()
                return
            }
            let string = date.httpHeader
            XCTAssertEqual(string, entry.1)
        }
    }
}
