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
import NIOConcurrencyHelpers
import Tracing

/// Endpoint path storage
public struct EndpointPath: Sendable {
    public init(eventLoop: EventLoop) {
        self._value = .init(nil)
    }

    /// Endpoint path
    public internal(set) var value: String? {
        get { self._value.withLockedValue{ $0 } }
        nonmutating set { self._value.withLockedValue { $0 = newValue } }
    }

    private let _value: NIOLockedValueBox<String?>
}

/// Request context values required by Hummingbird itself.
public struct HBCoreRequestContext: Sendable {
    /// Application context
    @usableFromInline
    let applicationContext: HBApplicationContext
    /// EventLoop request is running on
    @usableFromInline
    let eventLoop: EventLoop
    /// ByteBuffer allocator used by request
    @usableFromInline
    let allocator: ByteBufferAllocator
    /// Logger to use with Request
    @usableFromInline
    var logger: Logger
    /// Endpoint path
    @usableFromInline
    var endpointPath: EndpointPath
    /// Parameters extracted from URI
    @usableFromInline
    var parameters: HBParameters

    @inlinable
    public init(
        applicationContext: HBApplicationContext,
        eventLoop: EventLoop,
        logger: Logger,
        allocator: ByteBufferAllocator = .init()
    ) {
        self.applicationContext = applicationContext
        self.eventLoop = eventLoop
        self.allocator = allocator
        self.logger = logger
        self.endpointPath = .init(eventLoop: eventLoop)
        self.parameters = .init()
    }

    @inlinable
    public init(
        applicationContext: HBApplicationContext,
        channel: Channel,
        logger: Logger
    ) {
        self.init(applicationContext: applicationContext, eventLoop: channel.eventLoop, logger: logger, allocator: channel.allocator)
    }
}

/// Protocol that all request contexts should conform to. Holds data associated with
/// a request. Provides context for request processing
public protocol HBRequestContext: Sendable {
    /// Core context
    var coreContext: HBCoreRequestContext { get set }
    /// Service context
    var serviceContext: ServiceContext { get }
    /// initialize an `HBRequestContext`
    /// - Parameters:
    ///   - applicationContext: Context coming from Application
    ///   - channel: Channel that created request and context
    ///   - logger: Logger to use with request
    init(applicationContext: HBApplicationContext, channel: Channel, logger: Logger)
}

extension HBRequestContext {
    /// Application context
    @inlinable
    public var applicationContext: HBApplicationContext { coreContext.applicationContext }
    /// EventLoop request is running on. This is unavailable in concurrency contexts as you
    /// have already hopped off the EventLoop into a Task
    @inlinable
    @available(*, noasync)
    public var eventLoop: EventLoop { coreContext.eventLoop }
    /// ByteBuffer allocator used by request
    @inlinable
    public var allocator: ByteBufferAllocator { coreContext.allocator }
    /// Logger to use with Request
    @inlinable
    public var logger: Logger {
        get { coreContext.logger }
        set { coreContext.logger = newValue }
    }

    /// Endpoint path
    @inlinable
    public var endpointPath: String? { coreContext.endpointPath.value }
    /// Parameters extracted from URI
    @inlinable
    public var parameters: HBParameters { coreContext.parameters }
    /// default service context
    @inlinable
    public var serviceContext: ServiceContext { .topLevel }
    /// Request ID, extracted from Logger
    @inlinable
    public var id: String { self.logger[metadataKey: "hb_id"]!.description }

    /// Return failed `EventLoopFuture`
    @inlinable
    public func failure<T>(_ error: Error) -> EventLoopFuture<T> {
        return self.eventLoop.makeFailedFuture(error)
    }

    /// Return failed `EventLoopFuture` with http response status code
    @inlinable
    public func failure<T>(_ status: HTTPResponseStatus) -> EventLoopFuture<T> {
        return self.eventLoop.makeFailedFuture(HBHTTPError(status))
    }

    /// Return failed `EventLoopFuture` with http response status code and message
    @inlinable
    public func failure<T>(_ status: HTTPResponseStatus, message: String) -> EventLoopFuture<T> {
        return self.eventLoop.makeFailedFuture(HBHTTPError(status, message: message))
    }

    /// Return succeeded `EventLoopFuture`
    @inlinable
    public func success<T>(_ value: T) -> EventLoopFuture<T> {
        return self.eventLoop.makeSucceededFuture(value)
    }

    // Return new version of request with collated request body. If you want to process the
    // request body in middleware you need to call this to ensure you have the full request
    // body. Once this is called the request generated by this should be passed to the nextResponder
    @inlinable
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
    @inlinable
    public func collateBody(of request: HBRequest, maxSize: Int) -> EventLoopFuture<HBRequest> {
        request.body.consumeBody(maxSize: maxSize, on: self.eventLoop).flatMapThrowing { buffer in
            var request = request
            request.body = .byteBuffer(buffer)
            return request
        }
    }
}

/// Protocol for request context that stores the remote address of connected client
public protocol HBRemoteAddressRequestContext: HBRequestContext {
    /// Connected host address
    var remoteAddress: SocketAddress? { get }
}

/// Protocol for request context that supports tracing
public protocol HBTracingRequestContext: HBRequestContext {
    /// service context
    var serviceContext: ServiceContext { get set }
}

/// Implementation of a basic request context that supports everything the Hummingbird library needs
public struct HBBasicRequestContext: HBRequestContext, HBRemoteAddressRequestContext, HBTracingRequestContext {
    /// core context
    public var coreContext: HBCoreRequestContext
    /// ServiceContext
    public var serviceContext: ServiceContext
    /// Channel context
    let channel: Channel
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
        self.coreContext = .init(applicationContext: applicationContext, channel: channel, logger: logger)
        self.channel = channel
        self.serviceContext = .topLevel
    }
}
