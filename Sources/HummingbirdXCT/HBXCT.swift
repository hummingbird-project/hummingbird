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
import ServiceLifecycle

/// Response structure returned by XCT testing framework
public struct HBXCTResponse {
    /// response status
    public let status: HTTPResponseStatus
    /// response headers
    public let headers: HTTPHeaders
    /// response body
    public let body: ByteBuffer?
}

/// Errors thrown by XCT framework.
struct HBXCTError: Error, Equatable {
    private enum _Internal {
        case notStarted
        case noHead
        case illegalBody
        case noEnd
        case timeout
    }

    private let value: _Internal
    private init(_ value: _Internal) {
        self.value = value
    }

    static var notStarted: Self { .init(.notStarted) }
    static var noHead: Self { .init(.noHead) }
    static var illegalBody: Self { .init(.illegalBody) }
    static var noEnd: Self { .init(.noEnd) }
    static var timeout: Self { .init(.timeout) }
}

/// Protocol for client used by HBXCT
///
/// TODO: Could this be made Sendable? Currently HBXCTRouter.Client is not Sendable
/// Because `HBResponder` is not Sendable, Maybe in the future it could be and we
/// can revisit this
public protocol HBXCTClientProtocol {
    /// Execute URL request and provide response
    func execute(
        uri: String,
        method: HTTPMethod,
        headers: HTTPHeaders,
        body: ByteBuffer?
    ) async throws -> HBXCTResponse
}

extension HBXCTClientProtocol {
    /// Send request and call test callback on the response returned
    @discardableResult public func XCTExecute<Return>(
        uri: String,
        method: HTTPMethod,
        headers: HTTPHeaders = [:],
        body: ByteBuffer? = nil,
        testCallback: @escaping (HBXCTResponse) async throws -> Return = { $0 }
    ) async throws -> Return {
        let response = try await execute(uri: uri, method: method, headers: headers, body: body)
        return try await testCallback(response)
    }
}

/// Protocol for XCT framework.
public protocol HBXCT {
    /// Associated client with XCT server type
    associatedtype Client: HBXCTClientProtocol

    /// Run XCT server
    func run(application: HBApplication, _ test: @escaping @Sendable (any HBXCTClientProtocol) async throws -> Void) async throws
    /// Called once the XCT server is up and running
    func onServerRunning(_ channel: Channel) async
    /// EventLoopGroup used by XCT framework
    var eventLoopGroup: EventLoopGroup { get }
}

extension HBXCT {
    func onServerRunning(_: Channel) {}
}
