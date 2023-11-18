//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2023 the Hummingbird authors
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
import NIOConcurrencyHelpers
import NIOCore
import NIOPosix
import Tracing

/// Endpoint path storage
public struct EndpointPath: Sendable {
    public init() {
        self._value = .init(nil)
    }

    /// Endpoint path
    public internal(set) var value: String? {
        get { self._value.withLockedValue { $0 } }
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
    @usableFromInline
    var remoteAddress: SocketAddress?

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
        self.endpointPath = .init()
        self.parameters = .init()
        self.remoteAddress = nil
    }

    @inlinable
    public init(
        applicationContext: HBApplicationContext,
        channel: Channel,
        logger: Logger
    ) {
        self.applicationContext = applicationContext
        self.eventLoop = channel.eventLoop
        self.allocator = channel.allocator
        self.remoteAddress = channel.remoteAddress
        self.logger = logger
        self.endpointPath = .init()
        self.parameters = .init()
    }
}

/// Protocol that all request contexts should conform to. Holds data associated with
/// a request. Provides context for request processing
public protocol HBRequestContext: Sendable {
    /// Core context
    var coreContext: HBCoreRequestContext { get set }
    /// initialize an `HBRequestContext`
    /// - Parameters:
    ///   - logger: Logger to use with request
    init(coreContext: HBCoreRequestContext)
}

extension HBRequestContext {
    /// Application context
    @inlinable
    public var applicationContext: HBApplicationContext { coreContext.applicationContext }
    /// ThreadPool attached to application
    @inlinable
    public var threadPool: NIOThreadPool { self.coreContext.applicationContext.threadPool }
    /// EventLoop request is running on. This is unavailable in concurrency contexts as you
    /// have already hopped off the EventLoop into a Task
    /// ThreadPool attached to application
    @inlinable
    @available(*, noasync)
    public var eventLoop: EventLoop { coreContext.eventLoop }
    /// ByteBuffer allocator used by request
    @inlinable
    public var allocator: ByteBufferAllocator { coreContext.allocator }
    @inlinable
    public var remoteAddress: SocketAddress? { coreContext.remoteAddress }
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
    /// Request ID, extracted from Logger
    @inlinable
    public var id: String { self.logger[metadataKey: "hb_id"]!.description }
}

/// Protocol for request context that stores the remote address of connected client
public protocol HBRemoteAddressRequestContext: HBRequestContext {
    /// Connected host address
    var remoteAddress: SocketAddress? { get }
}

/// Implementation of a basic request context that supports everything the Hummingbird library needs
public struct HBBasicRequestContext: HBRequestContext, HBRemoteAddressRequestContext {
    /// core context
    public var coreContext: HBCoreRequestContext
    /// Connected host address
    public var remoteAddress: SocketAddress?

    ///  Initialize an `HBRequestContext`
    /// - Parameters:
    ///   - applicationContext: Context from Application that instigated the request
    ///   - channel: Channel that generated this request
    ///   - logger: Logger
    public init(coreContext: HBCoreRequestContext) {
        self.coreContext = coreContext
    }
}
