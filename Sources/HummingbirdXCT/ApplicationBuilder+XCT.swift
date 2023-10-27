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
public enum XCTLiveTestingSetup {
    /// Sets up a live server and execute tests using a HTTP client.
    case live
}

public enum XCTRouterTestingSetup {
    /// Test writing requests directly to router.
    case router
}

/// Extends `HBApplicationBuilder` to support testing of applications
///
/// You use `buildAndTest` and `XCTExecute` to test applications. You can either create an
/// `.router` application which send request directly to the router for testing your code or a
/// `.live` application. A `.router` application test is quicker and doesn't require setting up
/// a full server but will only test code run from request generation onwards.
///
/// The example below is using the `.router` framework to test
/// ```
/// let app = HBApplicationBuilder()
/// app.router.get("/hello") { _ in
///     return "hello"
/// }
/// app.buildAndTest(.router) { client in
///     // does my app return "hello" in the body for this route
///     client.XCTExecute(uri: "/hello", method: .GET) { response in
///         let body = try XCTUnwrap(response.body)
///         XCTAssertEqual(String(buffer: body, "hello")
///     }
/// }
/// ```
extension HBApplicationBuilder {
    // MARK: Initialization

    /// Creates a version of `HBApplication` that can be used for testing code
    ///
    /// - Parameters:
    ///   - testing: indicates which type of testing framework we want
    ///   - configuration: configuration of application
    public func buildAndTest<Value>(
        _: XCTLiveTestingSetup,
        _ test: @escaping @Sendable (any HBXCTClientProtocol) async throws -> Value
    ) async throws -> Value {
        let app: any HBXCTApplication
        app = HBXCTLive(builder: self)
        return try await app.run(test)
    }
}

extension HBApplicationBuilder where RequestContext: HBTestRouterContextProtocol {
    // MARK: Initialization

    /// Creates a version of `HBApplication` that can be used for testing code
    ///
    /// - Parameters:
    ///   - testing: indicates which type of testing framework we want
    ///   - configuration: configuration of application
    public func buildAndTest<Value>(
        _: XCTRouterTestingSetup,
        _ test: @escaping @Sendable (any HBXCTClientProtocol) async throws -> Value
    ) async throws -> Value {
        let app: any HBXCTApplication
        app = HBXCTRouter(builder: self)
        return try await app.run(test)
    }
}
