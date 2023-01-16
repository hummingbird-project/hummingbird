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
import XCTest

/// Type of test framework
public enum XCTTestingSetup {
    /// Test using SwiftNIO `EmbeddedChannel`. This is useful for testing where no actual IO or multi threading is required.
    case embedded
    /// Test using SwiftNIO `NIOAsyncTestingChannel`. This allows for testing of Swift Concurrency based routes.
    case asyncTest
    /// Sets up a live server and execute tests using a HTTP client.
    case live
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
        let xct: HBXCT
        let configuration = configuration.with(address: .hostname("localhost", port: 0))
        switch testing {
        case .embedded:
            xct = HBXCTEmbedded()
        case .live:
            xct = HBXCTLive(configuration: configuration, timeout: timeout)
        case .asyncTest:
            #if compiler(>=5.5.2) && canImport(_Concurrency)
            if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *) {
                xct = HBXCTAsyncTesting(timeout: timeout)
            } else {
                fatalError("XCTTestingSetup.asyncTest is not supported on your platform")
            }
            #else
            fatalError("XCTTestingSetup.asyncTest is not supported by version of Swift earlier than 5.5.2")
            xct = HBXCTEmbedded()
            #endif
        }
        self.init(configuration: configuration, eventLoopGroupProvider: .shared(xct.eventLoopGroup))
        self.extensions.set(\.xct, value: xct)
    }

    // MARK: Member variables

    public var xct: HBXCT {
        self.extensions.get(\.xct)
    }

    // MARK: Methods

    /// Start tests
    public func XCTStart() throws {
        try self.xct.start(application: self)
    }

    /// Stop tests
    public func XCTStop() {
        self.xct.stop(application: self)
    }

    /// Send request and call test callback on the response returned
    @discardableResult public func XCTExecute<Return>(
        uri: String,
        method: HTTPMethod,
        headers: HTTPHeaders = [:],
        body: ByteBuffer? = nil,
        testCallback: @escaping (HBXCTResponse) throws -> Return
    ) throws -> Return {
        return try self.xct.execute(uri: uri, method: method, headers: headers, body: body).flatMapThrowing { response in
            try testCallback(response)
        }.wait()
    }
}
