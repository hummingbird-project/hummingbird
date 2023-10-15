//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
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
public struct HBRouterMethodOptions: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// don't collate the request body, expect handler to stream it
    public static let streamBody: HBRouterMethodOptions = .init(rawValue: 1 << 0)
    /// allow handler to edit response via `request.response`
    public static let editResponse: HBRouterMethodOptions = .init(rawValue: 1 << 1)
}

/// Conform to `HBRouterMethods` to add standard router verb (get, post ...) methods
public protocol HBRouterMethods {
    /// Add path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult func on<Output: HBResponseGenerator>(
        _ path: String,
        method: HTTPMethod,
        options: HBRouterMethodOptions,
        use: @escaping (HBRequest, HBRequestContext) throws -> Output
    ) -> Self

    /// Add path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult func on<Output: HBResponseGenerator>(
        _ path: String,
        method: HTTPMethod,
        options: HBRouterMethodOptions,
        use: @escaping (HBRequest, HBRequestContext) -> EventLoopFuture<Output>
    ) -> Self

    /// Add path for async closure
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    @discardableResult func on<Output: HBResponseGenerator>(
        _ path: String,
        method: HTTPMethod,
        options: HBRouterMethodOptions,
        use: @escaping (HBRequest, HBRequestContext) async throws -> Output
    ) -> Self

    /// add group
    func group(_ path: String) -> HBRouterGroup
}

extension HBRouterMethods {
    /// GET path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func get<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping (HBRequest, HBRequestContext) throws -> Output
    ) -> Self {
        return on(path, method: .GET, options: options, use: handler)
    }

    /// PUT path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func put<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping (HBRequest, HBRequestContext) throws -> Output
    ) -> Self {
        return on(path, method: .PUT, options: options, use: handler)
    }

    /// POST path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func post<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping (HBRequest, HBRequestContext) throws -> Output
    ) -> Self {
        return on(path, method: .POST, options: options, use: handler)
    }

    /// HEAD path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func head<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping (HBRequest, HBRequestContext) throws -> Output
    ) -> Self {
        return on(path, method: .HEAD, options: options, use: handler)
    }

    /// DELETE path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func delete<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping (HBRequest, HBRequestContext) throws -> Output
    ) -> Self {
        return on(path, method: .DELETE, options: options, use: handler)
    }

    /// PATCH path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func patch<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping (HBRequest, HBRequestContext) throws -> Output
    ) -> Self {
        return on(path, method: .PATCH, options: options, use: handler)
    }

    /// GET path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func get<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping (HBRequest, HBRequestContext) -> EventLoopFuture<Output>
    ) -> Self {
        return on(path, method: .GET, options: options, use: handler)
    }

    /// PUT path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func put<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping (HBRequest, HBRequestContext) -> EventLoopFuture<Output>
    ) -> Self {
        return on(path, method: .PUT, options: options, use: handler)
    }

    /// DELETE path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func delete<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping (HBRequest, HBRequestContext) -> EventLoopFuture<Output>
    ) -> Self {
        return on(path, method: .DELETE, options: options, use: handler)
    }

    /// HEAD path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func head<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping (HBRequest, HBRequestContext) -> EventLoopFuture<Output>
    ) -> Self {
        return on(path, method: .HEAD, options: options, use: handler)
    }

    /// POST path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func post<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping (HBRequest, HBRequestContext) -> EventLoopFuture<Output>
    ) -> Self {
        return on(path, method: .POST, options: options, use: handler)
    }

    /// PATCH path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func patch<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping (HBRequest, HBRequestContext) -> EventLoopFuture<Output>
    ) -> Self {
        return on(path, method: .PATCH, options: options, use: handler)
    }
}

extension HBRouterMethods {
    func constructResponder<Output: HBResponseGenerator>(
        options: HBRouterMethodOptions,
        use closure: @escaping (HBRequest, HBRequestContext) throws -> Output
    ) -> HBResponder {
        // generate response from request. Moved repeated code into internal function
        func _respond(request: HBRequest, context: HBRequestContext) throws -> HBResponse {
            let response: HBResponse
            if options.contains(.editResponse) {
                var context = context
                context.response = .init()
                response = try closure(request, context).patchedResponse(from: request, context: context)
            } else {
                response = try closure(request, context).response(from: request, context: context)
            }
            return response
        }

        if options.contains(.streamBody) {
            return HBCallbackResponder { request, context in
                do {
                    let response = try _respond(request: request, context: context)
                    return context.success(response)
                } catch {
                    return context.failure(error)
                }
            }
        } else {
            return HBCallbackResponder { request, context in
                if case .byteBuffer = request.body {
                    do {
                        let response = try _respond(request: request, context: context)
                        return context.success(response)
                    } catch {
                        return context.failure(error)
                    }
                } else {
                    return request.body.consumeBody(
                        maxSize: context.applicationContext.configuration.maxUploadSize,
                        on: context.eventLoop
                    ).flatMapThrowing { buffer in
                        var request = request
                        request.body = .byteBuffer(buffer)
                        return try _respond(request: request, context: context)
                    }
                }
            }
        }
    }

    func constructResponder<Output: HBResponseGenerator>(
        options: HBRouterMethodOptions,
        use closure: @escaping (HBRequest, HBRequestContext) -> EventLoopFuture<Output>
    ) -> HBResponder {
        // generate response from request. Moved repeated code into internal function
        func _respond(request: HBRequest, context: HBRequestContext) -> EventLoopFuture<HBResponse> {
            var context = context
            let responseFuture: EventLoopFuture<HBResponse>
            if options.contains(.editResponse) {
                context.response = .init()
                responseFuture = closure(request, context).flatMapThrowing { try $0.patchedResponse(from: request, context: context) }
            } else {
                responseFuture = closure(request, context).flatMapThrowing { try $0.response(from: request, context: context) }
            }
            return responseFuture.hop(to: context.eventLoop)
        }

        if options.contains(.streamBody) {
            return HBCallbackResponder { request, context in
                return _respond(request: request, context: context)
            }
        } else {
            return HBCallbackResponder { request, context in
                var request = request
                if case .byteBuffer = request.body {
                    return _respond(request: request, context: context)
                } else {
                    return request.body.consumeBody(
                        maxSize: context.applicationContext.configuration.maxUploadSize,
                        on: context.eventLoop
                    ).flatMap { buffer in
                        request.body = .byteBuffer(buffer)
                        return _respond(request: request, context: context)
                    }
                }
            }
        }
    }
}
