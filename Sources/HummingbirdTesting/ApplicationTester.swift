//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

public import HTTPTypes
public import Hummingbird

/// Response structure returned by testing framework
public struct TestResponse: Sendable {
    public let head: HTTPResponse
    /// response status
    public var status: HTTPResponse.Status { self.head.status }
    /// response headers
    public var headers: HTTPFields { self.head.headerFields }
    /// response body
    public let body: ByteBuffer
    /// trailer headers
    public let trailerHeaders: HTTPFields?
}

/// Errors thrown by testing framework.
struct TestError: Error, Equatable {
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

/// Protocol for client used by HummingbirdTesting
public protocol TestClientProtocol: Sendable {
    /// Execute URL request and provide response
    func executeRequest(
        uri: String,
        method: HTTPRequest.Method,
        headers: HTTPFields,
        body: ByteBuffer?
    ) async throws -> TestResponse
    // Port to connect to if test client is connecting to a live server
    var port: Int? { get }
}

extension TestClientProtocol {
    /// Send request to associated test framework and call test callback on the response returned
    ///
    /// - Parameters:
    ///   - uri: Path of request
    ///   - method: Request method
    ///   - headers: Request headers
    ///   - body: Request body
    ///   - testCallback: closure to call on response returned by test framework
    /// - Returns: Return value of test closure
    @discardableResult public func execute<Return>(
        uri: String,
        method: HTTPRequest.Method,
        headers: HTTPFields = [:],
        body: ByteBuffer? = nil,
        testCallback: @escaping (TestResponse) async throws -> Return = { $0 }
    ) async throws -> Return {
        let response = try await executeRequest(uri: uri, method: method, headers: headers, body: body)
        return try await testCallback(response)
    }
}

/// Protocol for application test framework
protocol ApplicationTestFramework {
    /// Associated client for application test
    associatedtype Client: TestClientProtocol

    /// Run test server
    func run<Value>(_ test: @Sendable (Client) async throws -> Value) async throws -> Value
}
