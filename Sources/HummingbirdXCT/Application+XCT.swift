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

import Hummingbird
import NIOCore
import NIOHTTP1

/// Type of test framework
public enum XCTTestingSetup {
    /// Sets up a live server and execute tests using a HTTP client.
    case live
    /// Test writing requests directly to router.
    case router
}

/// Extends `HBApplication` to support testing of applications
///
/// You use `XCTStart`, `XCTStop` and `XCTExecute` to run test applications. You can either create an
/// "embedded" application which uses the `EmbeddedChannel` for testing your code or a "live" application.
/// An "embedded" application test is quicker and doesn't require setting up a full server but if you code is reliant
/// on multi-threading it will fail. In that situation you should use a "live" application which will setup a local server.
///
/// The example below is using the `.embedded` framework to test
/// ```
/// let app = HBApplication(testing: .embedded)
/// app.router.get("/hello") { _ in
///     return "hello"
/// }
/// app.XCTStart()
/// defer { app.XCTStop() }
///
/// // does my app return "hello" in the body for this route
/// app.XCTExecute(uri: "/hello", method: .GET) { response in
///     let body = try XCTUnwrap(response.body)
///     XCTAssertEqual(String(buffer: body, "hello")
/// }
/// ```
extension HBApplication {
    // MARK: Initialization

    /// Creates a version of `HBApplication` that can be used for testing code
    ///
    /// - Parameters:
    ///   - testing: indicates which type of testing framework we want
    ///   - configuration: configuration of application
    public convenience init(testing: XCTTestingSetup, configuration: HBApplication.Configuration = .init(), timeout: TimeAmount = .seconds(15)) {
        let xct: any HBXCT
        let configuration = configuration.with(address: .hostname("localhost", port: 0))
        switch testing {
        case .router:
            xct = HBXCTRouter()
        case .live:
            xct = HBXCTLive(configuration: configuration, timeout: timeout)
        }
        self.init(
            configuration: configuration,
            eventLoopGroupProvider: .shared(xct.eventLoopGroup),
            onServerRunning: { channel in
                await xct.onServerRunning(channel)
            }
        )
        self.extensions.set(\.xct, value: xct)
    }

    // MARK: Member variables

    public var xct: any HBXCT {
        self.extensions.get(\.xct)
    }

    // MARK: Methods

    /// Start tests
    public func XCTTest(_ test: @escaping @Sendable (any HBXCTClientProtocol) async throws -> Void) async throws {
        try await self.xct.run(application: self, test)
    }
}
