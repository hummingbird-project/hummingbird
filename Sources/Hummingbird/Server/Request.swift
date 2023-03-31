//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2022 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Atomics
import HummingbirdCore
import Logging
import NIOConcurrencyHelpers
import NIOCore
import NIOHTTP1

/// Holds all the values required to process a request
public struct HBRequest: Sendable, HBSendableExtensible {
    // MARK: Member variables

    /// URI path
    public var uri: HBURL { self._internal.uri }
    /// HTTP version
    public var version: HTTPVersion { self._internal.version }
    /// Request HTTP method
    public var method: HTTPMethod { self._internal.method }
    /// Request HTTP headers
    public var headers: HTTPHeaders { self._internal.headers }
    /// Body of HTTP request
    public var body: HBRequestBody
    /// Logger to use
    public var logger: Logger
    /// reference to application
    public var application: HBApplication { self._internal.application.wrappedValue }
    /// Request extensions
    public var extensions: HBSendableExtensions<HBRequest>
    /// Request context (eventLoop, bytebuffer allocator and remote address)
    public var context: HBRequestContext { self._internal.context }
    /// EventLoop request is running on
    public var eventLoop: EventLoop { self._internal.context.eventLoop }
    /// ByteBuffer allocator used by request
    public var allocator: ByteBufferAllocator { self._internal.context.allocator }
    /// IP request came from
    public var remoteAddress: SocketAddress? { self._internal.context.remoteAddress }

    /// Request ID (Uses ID attached to loggger to avoid replication)
    public var id: String { self.logger[metadataKey: "hb_id"]!.description }

    /// Parameters extracted during processing of request URI. These are available to you inside the route handler
    public var parameters: HBParameters {
        get {
            self.extensions.get(\.parameters) ?? .init()
        }
        set { self.extensions.set(\.parameters, value: newValue) }
    }

    /// endpoint that services this request.
    public internal(set) var endpointPath: String? {
        get { self._internal.endpointPath.wrappedValue }
        set { self._internal.endpointPath.wrappedValue = newValue }
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
        self._internal = .init(
            uri: .init(head.uri),
            version: head.version,
            method: head.method,
            headers: head.headers,
            application: application,
            context: context
        )
        self.body = body
        self.logger = application.logger.with(metadataKey: "hb_id", value: .stringConvertible(Self.globalRequestID.loadThenWrappingIncrement(by: 1, ordering: .relaxed)))
        self.extensions = .init()
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

    // Return new version of request with collated request body. If you want to process the
    // request body in middleware you need to call this to ensure you have the full request
    // body. Once this is called the request generated by this should be passed to the nextResponder
    public func collateBody() -> EventLoopFuture<HBRequest> {
        self.body.consumeBody(
            maxSize: self.application.configuration.maxUploadSize,
            on: self.eventLoop
        ).flatMapThrowing { buffer in
            var request = self
            request.body = .byteBuffer(buffer)
            return request
        }
    }

    // Return new version of request with collated request body. If you want to process the
    // request body in middleware you need to call this to ensure you have the full request
    // body. Once this is called the request generated by this should be passed to the nextResponder
    public func collateBody(maxSize: Int) -> EventLoopFuture<HBRequest> {
        self.body.consumeBody(maxSize: maxSize, on: self.eventLoop).flatMapThrowing { buffer in
            var request = self
            request.body = .byteBuffer(buffer)
            return request
        }
    }

    /// Store all the read-only values of the request in a class to avoid copying them
    /// everytime we pass the `HBRequest` struct about
    final class _Internal: Sendable {
        internal init(uri: HBURL, version: HTTPVersion, method: HTTPMethod, headers: HTTPHeaders, application: HBApplication, context: HBRequestContext, endpointPath: String? = nil) {
            self.uri = uri
            self.version = version
            self.method = method
            self.headers = headers
            self.application = .init(application)
            self.context = context
            self.endpointPath = .init(endpointPath)
        }

        /// URI path
        let uri: HBURL
        /// HTTP version
        let version: HTTPVersion
        /// Request HTTP method
        let method: HTTPMethod
        /// Request HTTP headers
        let headers: HTTPHeaders
        /// reference to application. Currently wrapped in HBUnsafeTransfer to make Sendable.
        /// Hope to make it Sendable in the future
        let application: HBUnsafeTransfer<HBApplication>
        /// request context
        let context: HBRequestContext
        /// Endpoint path. This is stored a var so it can be edited by the router. In theory this could
        /// be accessed on multiple thread/tasks at the same point but it is only ever edited by router
        let endpointPath: HBUnsafeMutableTransferBox<String?>
    }

    private var _internal: _Internal

    private static let globalRequestID = ManagedAtomic(0)
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

extension HBRequest: CustomStringConvertible {
    public var description: String {
        "uri: \(self.uri), version: \(self.version), method: \(self.method), headers: \(self.headers), body: \(self.body)"
    }
}
