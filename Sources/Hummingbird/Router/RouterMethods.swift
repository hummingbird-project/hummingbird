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

import NIOCore
import NIOHTTP1

/// Options available to routes
public struct HBRouterMethodOptions: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// don't collate the request body, expect handler to stream it
    public static let streamBody: HBRouterMethodOptions = .init(rawValue: 1 << 0)
}

/// Conform to `HBRouterMethods` to add standard router verb (get, post ...) methods
public protocol HBRouterMethods {
    associatedtype Context: HBRequestContext

    /// Add path for async closure
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    @discardableResult func on<Output: HBResponseGenerator>(
        _ path: String,
        method: HTTPMethod,
        options: HBRouterMethodOptions,
        use: @Sendable @escaping (HBRequest, Context) async throws -> Output
    ) -> Self

    /// add group
    func group(_ path: String) -> HBRouterGroup<Context>
}

extension HBRouterMethods {
    /// GET path for async closure returning type conforming to ResponseEncodable
    @discardableResult public func get<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @Sendable @escaping (HBRequest, Context) async throws -> Output
    ) -> Self {
        return on(path, method: .GET, options: options, use: handler)
    }

    /// PUT path for async closure returning type conforming to ResponseEncodable
    @discardableResult public func put<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @Sendable @escaping (HBRequest, Context) async throws -> Output
    ) -> Self {
        return on(path, method: .PUT, options: options, use: handler)
    }

    /// DELETE path for async closure returning type conforming to ResponseEncodable
    @discardableResult public func delete<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @Sendable @escaping (HBRequest, Context) async throws -> Output
    ) -> Self {
        return on(path, method: .DELETE, options: options, use: handler)
    }

    /// HEAD path for async closure returning type conforming to ResponseEncodable
    @discardableResult public func head<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @Sendable @escaping (HBRequest, Context) async throws -> Output
    ) -> Self {
        return on(path, method: .HEAD, options: options, use: handler)
    }

    /// POST path for async closure returning type conforming to ResponseEncodable
    @discardableResult public func post<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @Sendable @escaping (HBRequest, Context) async throws -> Output
    ) -> Self {
        return on(path, method: .POST, options: options, use: handler)
    }

    /// PATCH path for async closure returning type conforming to ResponseEncodable
    @discardableResult public func patch<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @Sendable @escaping (HBRequest, Context) async throws -> Output
    ) -> Self {
        return on(path, method: .PATCH, options: options, use: handler)
    }

    func constructResponder<Output: HBResponseGenerator>(
        options: HBRouterMethodOptions,
        use closure: @Sendable @escaping (HBRequest, Context) async throws -> Output
    ) -> HBCallbackResponder<Context> {
        return HBCallbackResponder { request, context in
            if options.contains(.streamBody) {
                let output = try await closure(request, context)
                return try output.response(from: request, context: context)
            } else {
                var request = request
                do {
                    request.body = try await request.body.collate(maxSize: context.applicationContext.configuration.maxUploadSize)
                } catch {
                    throw HBHTTPError(.payloadTooLarge)
                }
                let output = try await closure(request, context)
                return try output.response(from: request, context: context)
            }
        }
    }
}
