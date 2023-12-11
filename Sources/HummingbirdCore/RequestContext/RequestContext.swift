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
    public package(set) var value: String? {
        get { self._value.withLockedValue { $0 } }
        nonmutating set { self._value.withLockedValue { $0 = newValue } }
    }

    private let _value: NIOLockedValueBox<String?>
}

public struct HBRequestContextConfiguration: Sendable {
    public let maxUploadSize: Int

    package init(maxUploadSize: Int) {
        self.maxUploadSize = maxUploadSize
    }
}

/// Request context values required by Hummingbird itself.
public struct HBCoreRequestContext: Sendable {
    @usableFromInline
    var configuration: HBRequestContextConfiguration
    /// Request decoder
    @usableFromInline
    var requestDecoder: HBRequestDecoder
    /// Response encoder
    @usableFromInline
    var responseEncoder: HBResponseEncoder
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
    package var endpointPath: EndpointPath

    @inlinable
    public init(
        configuration: HBRequestContextConfiguration,
        requestDecoder: HBRequestDecoder = NullDecoder(),
        responseEncoder: HBResponseEncoder = NullEncoder(),
        eventLoop: EventLoop,
        allocator: ByteBufferAllocator,
        logger: Logger
    ) {
        self.configuration = configuration
        self.requestDecoder = requestDecoder
        self.responseEncoder = responseEncoder
        self.eventLoop = eventLoop
        self.allocator = allocator
        self.logger = logger
        self.endpointPath = .init()
    }
}

/// Protocol that all request contexts should conform to. Holds data associated with
/// a request. Provides context for request processing
public protocol HBBaseRequestContext: Sendable {
    /// Core context
    var coreContext: HBCoreRequestContext { get set }
    /// Thread Pool
    var threadPool: NIOThreadPool { get }
}

extension HBBaseRequestContext {
    public package(set) var requestDecoder: HBRequestDecoder {
        get { self.coreContext.requestDecoder }
        set { self.coreContext.requestDecoder = newValue }
    }
    public package(set) var responseEncoder: HBResponseEncoder {
        get { self.coreContext.responseEncoder }
        set { self.coreContext.responseEncoder = newValue }
    }
    @inlinable
    public var maxUploadSize: Int { self.coreContext.configuration.maxUploadSize }
    /// ThreadPool attached to application
    @inlinable
    public var threadPool: NIOThreadPool { NIOThreadPool.singleton }
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
    /// Request ID, extracted from Logger
    @inlinable
    public var id: String { self.logger[metadataKey: "hb_id"]!.description }
}