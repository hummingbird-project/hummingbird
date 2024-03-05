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
import HummingbirdCore
import NIOCore

/// HTTP Scheme to use with AsyncHTTPClient test framework
public enum XCTScheme: String {
    case http
    case https
}

/// Type of test framework
public struct XCTTestingSetup {
    enum Internal {
        case router
        case live
        case ahc(XCTScheme)
    }

    let value: Internal

    /// Test writing requests directly to router.
    public static var router: XCTTestingSetup { .init(value: .router) }
    /// Sets up a live server and execute tests using a HTTP client. Only supports HTTP1
    public static var live: XCTTestingSetup { .init(value: .live) }
    /// Sets up a live server and execute tests using a HTTP client. Does not support trailer headers
    public static func ahc(_ scheme: XCTScheme) -> XCTTestingSetup { .init(value: .ahc(scheme)) }
}

/// Extends `HBApplicationProtocol` to support testing of applications
extension HBApplicationProtocol where Responder.Context: HBRequestContext {
    // MARK: Initialization

    /// Test `HBApplication`
    ///
    /// You use `test` and `XCTExecute` to test applications. You can either test using
    /// the `.router` test framework which sends requests directly to the router for testing your code or
    /// the `.live` or `.ahc` frameworks which both run live servers to pass requests to, but provide
    /// a single connection HTTP client or AsyncHTTPClient as a client respectively . The `.router` test
    /// framework is quicker and doesn't require setting up a full server but will only test code run
    /// from request generation onwards.
    ///
    /// The example below is using the `.router` framework to test
    /// ```swift
    /// let router = HBRouter()
    /// router.get("/hello") { _ in
    ///     return "hello"
    /// }
    /// let app = HBApplication(router: router)
    /// app.test(.router) { client in
    ///     // does my app return "hello" in the body for this route
    ///     client.XCTExecute(uri: "/hello", method: .GET) { response in
    ///         XCTAssertEqual(String(buffer: response.body), "hello")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - testing: indicates which type of testing framework we want
    ///   - configuration: configuration of application
    public func test<Value>(
        _ testingSetup: XCTTestingSetup,
        _ test: @escaping @Sendable (any HBXCTClientProtocol) async throws -> Value
    ) async throws -> Value {
        let app: any HBXCTApplication = switch testingSetup.value {
        case .router: try await HBXCTRouter(app: self)
        case .live: HBXCTLive(app: self)
        case .ahc(let scheme): HBXCTAsyncHTTPClient(app: self, scheme: scheme)
        }
        return try await app.run(test)
    }
}
