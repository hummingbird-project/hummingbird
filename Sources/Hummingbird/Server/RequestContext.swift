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
import Logging
import NIOCore
import Tracing

/// Endpoint path storage
public struct EndpointPath: Sendable {
    public init(eventLoop: EventLoop) {
        self._value = .init(nil, eventLoop: eventLoop)
    }

    /// Endpoint path
    public internal(set) var value: String? {
        get { self._value.value }
        nonmutating set { self._value.value = newValue }
    }

    private let _value: NIOLoopBoundBox<String?>
}

public protocol HBRequestContext: Sendable {
    /// Application context
    var applicationContext: HBApplicationContext { get }
    /// Logger to use with Request
    var logger: Logger { get }
    /// EventLoop request is running on
    var eventLoop: EventLoop { get }
    /// ByteBuffer allocator used by request
    var allocator: ByteBufferAllocator { get }
    /// Endpoint path
    var endpointPath: EndpointPath { get }
    /// Parameters extracted from URI
    var parameters: HBParameters { get set }
    /// request ID
    var requestId: Int { get }
    /// service context
    var serviceContext: ServiceContext { get set }
    /// Default init
    init(applicationContext: HBApplicationContext, channel: Channel)
}

extension HBRequestContext {
    static func create(applicationContext: HBApplicationContext, channel: Channel) -> Self {
        return .init(applicationContext: applicationContext, channel: channel)
    }
}

public protocol HBChannelContext {
    /// channel that created request
    var channel: Channel { get }
}

/// Holds data associated with a request. Provides context for request processing
public struct HBBasicRequestContext: HBRequestContext, HBChannelContext, HBSendableExtensible {
    /// Application context
    public let applicationContext: HBApplicationContext
    /// Channel context (where to get EventLoop, allocator etc)
    public let channel: Channel
    /// Logger to use with Request
    public let logger: Logger
    /// Request ID
    public let requestId: Int
    /// Endpoint path
    public let endpointPath: EndpointPath

    /// ServiceContext
    public var serviceContext: ServiceContext
    /// Extensions
    public var extensions: HBSendableExtensions<HBBasicRequestContext>

    /// EventLoop request is running on
    public var eventLoop: EventLoop { self.channel.eventLoop }
    /// ByteBuffer allocator used by request
    public var allocator: ByteBufferAllocator { self.channel.allocator }
    /// Connected host address
    public var remoteAddress: SocketAddress? { self.channel.remoteAddress }
    /// Current global request ID
    private static let globalRequestID = ManagedAtomic(0)

    ///  Initialize an `HBRequestContext`
    /// - Parameters:
    ///   - applicationContext: Context from Application that instigated the request
    ///   - channelContext: Context providing source for EventLoop
    public init(
        applicationContext: HBApplicationContext,
        channel: Channel
    ) {
        self.applicationContext = applicationContext
        self.channel = channel
        self.requestId = Self.globalRequestID.loadThenWrappingIncrement(by: 1, ordering: .relaxed)
        self.logger = self.applicationContext.logger.with(metadataKey: "hb_id", value: .stringConvertible(self.requestId))
        self.serviceContext = .topLevel
        self.extensions = .init()
        self.endpointPath = .init(eventLoop: channel.eventLoop)
    }

    /// Parameters extracted during processing of request URI. These are available to you inside the route handler
    public var parameters: HBParameters {
        @inlinable get {
            self.extensions.get(\.parameters) ?? .init()
        }
        @inlinable set { self.extensions.set(\.parameters, value: newValue) }
    }
}

extension HBRequestContext {
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
    public func collateBody(of request: HBRequest) -> EventLoopFuture<HBRequest> {
        request.body.consumeBody(
            maxSize: self.applicationContext.configuration.maxUploadSize,
            on: self.eventLoop
        ).flatMapThrowing { buffer in
            var request = request
            request.body = .byteBuffer(buffer)
            return request
        }
    }

    // Return new version of request with collated request body. If you want to process the
    // request body in middleware you need to call this to ensure you have the full request
    // body. Once this is called the request generated by this should be passed to the nextResponder
    public func collateBody(of request: HBRequest, maxSize: Int) -> EventLoopFuture<HBRequest> {
        request.body.consumeBody(maxSize: maxSize, on: self.eventLoop).flatMapThrowing { buffer in
            var request = request
            request.body = .byteBuffer(buffer)
            return request
        }
    }
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
