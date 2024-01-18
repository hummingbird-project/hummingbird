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
    public var value: String? {
        get { self._value.withLockedValue { $0 } }
        nonmutating set { self._value.withLockedValue { $0 = newValue } }
    }

    private let _value: NIOLockedValueBox<String?>
}

/// Request context values required by Hummingbird itself.
public struct HBCoreRequestContext: Sendable {
    /// Request decoder
    @usableFromInline
    var requestDecoder: HBRequestDecoder
    /// Response encoder
    @usableFromInline
    var responseEncoder: HBResponseEncoder
    /// ByteBuffer allocator used by request
    @usableFromInline
    let allocator: ByteBufferAllocator
    /// Logger to use with Request
    @usableFromInline
    var logger: Logger
    /// Endpoint path
    public var endpointPath: EndpointPath
    /// Parameters extracted from URI
    public var parameters: HBParameters

    @inlinable
    public init(
        requestDecoder: HBRequestDecoder = NullDecoder(),
        responseEncoder: HBResponseEncoder = NullEncoder(),
        allocator: ByteBufferAllocator,
        logger: Logger
    ) {
        self.requestDecoder = requestDecoder
        self.responseEncoder = responseEncoder
        self.allocator = allocator
        self.logger = logger
        self.endpointPath = .init()
        self.parameters = .init()
    }
}

/// Protocol that all request contexts should conform to. Holds data associated with
/// a request. Provides context for request processing
public protocol HBBaseRequestContext: Sendable {
    /// Core context
    var coreContext: HBCoreRequestContext { get set }
    /// Thread Pool
    var threadPool: NIOThreadPool { get }
    /// Maximum upload size allowed for routes that don't stream the request payload. This
    /// limits how much memory would be used for one request
    var maxUploadSize: Int { get }
}

extension HBBaseRequestContext {
    /// Request decoder
    @inlinable
    public var requestDecoder: HBRequestDecoder { coreContext.requestDecoder }
    /// Response encoder
    @inlinable
    public var responseEncoder: HBResponseEncoder { coreContext.responseEncoder }
    /// ThreadPool attached to application
    @inlinable
    public var threadPool: NIOThreadPool { NIOThreadPool.singleton }
    /// ByteBuffer allocator used by request
    @inlinable
    public var allocator: ByteBufferAllocator { coreContext.allocator }
    /// Logger to use with Request
    @inlinable
    public var logger: Logger {
        get { coreContext.logger }
        set { coreContext.logger = newValue }
    }

    /// maxUploadSize
    @inlinable
    public var maxUploadSize: Int { 2 * 1024 * 1024 }
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

/// Protocol for a request context that can be created from a NIO Channel
public protocol HBRequestContext: HBBaseRequestContext {
    /// initialize an `HBRequestContext`
    /// - Parameters:
    ///   - channel: Channel that initiated this request
    ///   - logger: Logger used for this request
    init(channel: Channel, logger: Logger)
    /// initialize an `HBRequestContext`
    /// - Parameters
    ///   - allocator: ByteBuffer allocator
    ///   - logger: Logger used for this request
    init(allocator: ByteBufferAllocator, logger: Logger)
}

extension HBRequestContext {
    ///  Initialize an `HBRequestContext`
    /// - Parameters:
    ///   - channel: Channel that initiated this request
    ///   - logger: Logger used for this request
    public init(channel: Channel, logger: Logger) {
        self.init(allocator: channel.allocator, logger: logger)
    }
}

/// Implementation of a basic request context that supports everything the Hummingbird library needs
public struct HBBasicRequestContext: HBRequestContext {
    /// core context
    public var coreContext: HBCoreRequestContext

    ///  Initialize an `HBRequestContext`
    /// - Parameters:
    ///   - allocator: Allocator
    ///   - logger: Logger
    public init(
        allocator: ByteBufferAllocator,
        logger: Logger
    ) {
        self.coreContext = .init(
            allocator: allocator,
            logger: logger
        )
    }
}
