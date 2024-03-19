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
public struct CoreRequestContext: Sendable {
    /// ByteBuffer allocator used by request
    @usableFromInline
    let allocator: ByteBufferAllocator
    /// Logger to use with Request
    @usableFromInline
    var logger: Logger
    /// Endpoint path
    public var endpointPath: EndpointPath
    /// Parameters extracted from URI
    public var parameters: Parameters

    @inlinable
    public init(
        allocator: ByteBufferAllocator,
        logger: Logger
    ) {
        self.allocator = allocator
        self.logger = logger
        self.endpointPath = .init()
        self.parameters = .init()
    }
}

/// Protocol that all request contexts should conform to. Holds data associated with
/// a request. Provides context for request processing
public protocol BaseRequestContext: Sendable {
    associatedtype Decoder: RequestDecoder = JSONDecoder
    associatedtype Encoder: ResponseEncoder = JSONEncoder

    /// Core context
    var coreContext: CoreRequestContext { get set }
    /// Maximum upload size allowed for routes that don't stream the request payload. This
    /// limits how much memory would be used for one request
    var maxUploadSize: Int { get }
    /// Request decoder
    var requestDecoder: Decoder { get }
    /// Response encoder
    var responseEncoder: Encoder { get }
}

extension BaseRequestContext {
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
    public var parameters: Parameters { coreContext.parameters }
    /// Request ID, extracted from Logger
    @inlinable
    public var id: String { self.logger[metadataKey: "hb_id"]!.description }
}

extension BaseRequestContext where Decoder == JSONDecoder {
    public var requestDecoder: Decoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension BaseRequestContext where Encoder == JSONEncoder {
    public var responseEncoder: Encoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

/// Protocol for a request context that can be created from a NIO Channel
public protocol RequestContext: BaseRequestContext {
    /// initialize an `RequestContext`
    /// - Parameters:
    ///   - channel: Channel that initiated this request
    ///   - logger: Logger used for this request
    init(channel: Channel, logger: Logger)
}

/// Implementation of a basic request context that supports everything the Hummingbird library needs
public struct BasicRequestContext: RequestContext {
    /// core context
    public var coreContext: CoreRequestContext

    ///  Initialize an `RequestContext`
    /// - Parameters:
    ///   - allocator: Allocator
    ///   - logger: Logger
    public init(channel: Channel, logger: Logger) {
        self.coreContext = .init(
            allocator: channel.allocator,
            logger: logger
        )
    }
}
