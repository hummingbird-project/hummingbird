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
    func testRFC1123Renderer() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyy HH:mm:ss z"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        for _ in 0..<1000 {
            let time = Int.random(in: 1...4 * Int(Int32.max))
            XCTAssertEqual(formatter.string(from: Date(timeIntervalSince1970: Double(time))), DateCache.formatRFC1123Date(time))
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
}
