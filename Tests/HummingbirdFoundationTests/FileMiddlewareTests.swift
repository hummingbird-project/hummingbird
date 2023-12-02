//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Hummingbird
@testable import HummingbirdFoundation
import HummingbirdXCT
import XCTest

final class FileMiddlewareTests: XCTestCase {
    func testSearchForIndexHtml() throws {
        let tmp = NSTemporaryDirectory() + UUID().uuidString + "/"
        try FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: tmp + "index.html", contents: Data())
        addTeardownBlock {
            try? FileManager.default.removeItem(atPath: tmp)
        }

        let app = HBApplication(testing: .live)
        app.middleware.add(HBFileMiddleware(
            tmp,
            searchForIndexHtml: true,
            application: app
        ))
        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(uri: "/index.html", method: .GET) { response in
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(response.headers.first(name: "content-type"), "text/html")
        }

        try app.XCTExecute(uri: "/", method: .GET) { response in
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(response.headers.first(name: "content-type"), "text/html")
        }

        try app.XCTExecute(uri: "/\(UUID()).html", method: .GET) { response in
            XCTAssertEqual(response.status, .notFound)
        }
    }
}
