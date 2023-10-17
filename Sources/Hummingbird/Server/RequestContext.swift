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
    /// Service context
    var serviceContext: ServiceContext { get }
    /// Default init
    init(applicationContext: HBApplicationContext, channel: Channel, logger: Logger)
}

extension HBRequestContext {
    static func create(applicationContext: HBApplicationContext, channel: Channel, logger: Logger) -> Self {
        return .init(applicationContext: applicationContext, channel: channel, logger: logger)
    }

    var serviceContext: ServiceContext { .topLevel }

    var id: String { self.logger[metadataKey: "hb_id"]!.description }
}

/// Protocol for request context that stores the Channel that created it
public protocol HBRemoteAddressRequestContext: HBRequestContext {
    /// Connected host address
    var remoteAddress: SocketAddress? { get }
}

/// Protocol for request context that supports tracing
public protocol HBTracingRequestContext: HBRequestContext {
    /// service context
    var serviceContext: ServiceContext { get set }
}

/// Holds data associated with a request. Provides context for request processing
public struct HBBasicRequestContext: HBRequestContext, HBRemoteAddressRequestContext, HBTracingRequestContext {
    /// Application context
    public let applicationContext: HBApplicationContext
    /// Logger to use with Request
    public let logger: Logger
    /// Endpoint path
    public let endpointPath: EndpointPath
    /// Parameters extracted during processing of request URI. These are available to you inside the route handler
    public var parameters: HBParameters

    /// ServiceContext
    public var serviceContext: ServiceContext

    /// Channel context (where to get EventLoop, allocator etc)
    let channel: Channel
    /// EventLoop request is running on
    public var eventLoop: EventLoop { self.channel.eventLoop }
    /// ByteBuffer allocator used by request
    public var allocator: ByteBufferAllocator { self.channel.allocator }
    /// Connected host address
    public var remoteAddress: SocketAddress? { self.channel.remoteAddress }

    ///  Initialize an `HBRequestContext`
    /// - Parameters:
    ///   - applicationContext: Context from Application that instigated the request
    ///   - channelContext: Context providing source for EventLoop
    public init(
        applicationContext: HBApplicationContext,
        channel: Channel,
        logger: Logger
    ) {
        self.applicationContext = applicationContext
        self.channel = channel
        self.logger = logger
        self.serviceContext = .topLevel
        self.parameters = .init()
        self.endpointPath = .init(eventLoop: channel.eventLoop)
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
