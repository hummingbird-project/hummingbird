//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2024 the Hummingbird authors
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

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

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
public struct CoreRequestContextStorage: Sendable {
    /// Logger to use with Request
    @usableFromInline
    var logger: Logger
    /// Endpoint path
    public var endpointPath: EndpointPath
    /// Parameters extracted from URI
    public var parameters: Parameters

    @inlinable
    public init(
        source: some RequestContextSource
    ) {
        self.logger = source.logger
        self.endpointPath = .init()
        self.parameters = .init()
    }
}

/// Protocol that all request contexts should conform to. A RequestContext is a statically typed metadata container for information
/// that is associated with a ``HummingbirdCore/Request``, and is therefore instantiated alongside the request.
///
/// It's passed along the whole middleware chain through to the route. This allows middleware and the route to share this metadata.
///
/// Typical use of a context includes:
/// - The origin that sent the request (IP address or otherwise)
/// - The identity, such as a user, that is associated with this request
///
/// The context is a statically typed metadata container for the duration of a single request.
/// It's used to store values between middleware and routes such as the user's identity.
///
/// The lifetime of a RequestContext should not exceed that of the request.
public protocol RequestContext: InitializableFromSource, RequestContextSource {
    associatedtype Source: RequestContextSource = ApplicationRequestContextSource
    associatedtype Decoder: RequestDecoder = JSONDecoder
    associatedtype Encoder: ResponseEncoder = JSONEncoder

    /// Core context
    var coreContext: CoreRequestContextStorage { get set }
    /// Maximum size of request body allowed when decoding requests. If a request body
    /// that needs decoding is greater than this size then a Content Too Large (413)
    /// response is returned. This only applies to decoding requests.
    var maxUploadSize: Int { get }
    /// Request decoder
    var requestDecoder: Decoder { get }
    /// Response encoder
    var responseEncoder: Encoder { get }
}

extension RequestContext {
    /// Logger to use with Request
    @inlinable
    public var logger: Logger {
        get { coreContext.logger }
        set { coreContext.logger = newValue }
    }

    /// Maximum size of request body allowed when decoding requests.
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
    public var id: String { self.logger[metadataKey: "hb.request.id"]!.description }
}

extension RequestContext where Decoder == JSONDecoder {
    public var requestDecoder: Decoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension RequestContext where Encoder == JSONEncoder {
    public var responseEncoder: Encoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

/// Implementation of a basic request context that supports everything the Hummingbird library needs
public struct BasicRequestContext: RequestContext {
    /// core context
    public var coreContext: CoreRequestContextStorage

    ///  Initialize an `RequestContext`
    /// - Parameters:
    ///   - allocator: Allocator
    ///   - logger: Logger
    public init(source: Source) {
        self.coreContext = .init(source: source)
    }
}
