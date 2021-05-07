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

import HummingbirdCore
import Logging
import NIO
import NIOConcurrencyHelpers
import NIOHTTP1

/// Holds all the values required to process a request
public final class HBRequest: HBExtensible {
    // MARK: Member variables

    /// URI path
    public var uri: HBURL
    /// HTTP version
    public var version: HTTPVersion
    /// Request HTTP method
    public var method: HTTPMethod
    /// Request HTTP headers
    public var headers: HTTPHeaders
    /// Body of HTTP request
    public var body: HBRequestBody
    /// Logger to use
    public var logger: Logger
    /// reference to application
    public var application: HBApplication
    /// Request extensions
    public var extensions: HBExtensions<HBRequest>
    /// endpoint that services this request
    public var endpointPath: String?

    public var context: HBRequestContext
    /// EventLoop request is running on
    public var eventLoop: EventLoop { self.context.eventLoop }
    /// ByteBuffer allocator used by request
    public var allocator: ByteBufferAllocator { self.context.allocator }
    /// IP request came from
    public var remoteAddress: SocketAddress? { self.context.remoteAddress }

    /// Parameters extracted during processing of request URI. These are available to you inside the route handler
    public var parameters: HBParameters {
        get { self.extensions.getOrCreate(\.parameters, .init()) }
        set { self.extensions.set(\.parameters, value: newValue) }
    }

    // MARK: Initialization

    /// Create new HBRequest
    /// - Parameters:
    ///   - head: HTTP head
    ///   - body: HTTP body
    ///   - application: reference to application that created this request
    ///   - eventLoop: EventLoop request processing is running on
    ///   - allocator: Allocator used by channel request processing is running on
    public init(
        head: HTTPRequestHead,
        body: HBRequestBody,
        application: HBApplication,
        context: HBRequestContext
    ) {
        self.uri = .init(head.uri)
        self.version = head.version
        self.method = head.method
        self.headers = head.headers
        self.body = body
        self.logger = application.logger.with(metadataKey: "hb_id", value: .stringConvertible(Self.globalRequestID.add(1)))
        self.application = application
        self.extensions = HBExtensions()
        self.endpointPath = nil
        self.context = context
    }

    // MARK: Methods

    /// Decode request using decoder stored at `HBApplication.decoder`.
    /// - Parameter type: Type you want to decode to
    public func decode<Type: Decodable>(as type: Type.Type) throws -> Type {
        do {
            return try self.application.decoder.decode(type, from: self)
        } catch {
            self.logger.debug("Decode Error: \(error)")
            throw HBHTTPError(.badRequest)
        }
    }

    /// Return failed `EventLoopFuture`
    public func failure<T>(_ error: Error) -> EventLoopFuture<T> {
        return self.eventLoop.makeFailedFuture(error)
    }

    /// Return failed `EventLoopFuture` with http response status code
    public func failure<T>(_ status: HTTPResponseStatus) -> EventLoopFuture<T> {
        return self.eventLoop.makeFailedFuture(HBHTTPError(status))
    }

    /// Return failed `EventLoopFuture` with http response status code and message
    public func failure<T>(_ status: HTTPResponseStatus, message: String) -> EventLoopFuture<T> {
        return self.eventLoop.makeFailedFuture(HBHTTPError(status, message: message))
    }

    /// Return succeeded `EventLoopFuture`
    public func success<T>(_ value: T) -> EventLoopFuture<T> {
        return self.eventLoop.makeSucceededFuture(value)
    }

    private static let globalRequestID = NIOAtomic<Int>.makeAtomic(value: 0)
}

extension Logger {
    /// Create new Logger with additional metadata value
    /// - Parameters:
    ///   - metadataKey: Metadata key
    ///   - value: Metadata value
    /// - Returns: Logger
    func with(metadataKey: String, value: MetadataValue) -> Logger {
        var logger = self
        logger[metadataKey: metadataKey] = value
        return logger
    }
}
