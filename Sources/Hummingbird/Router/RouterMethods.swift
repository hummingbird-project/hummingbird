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

public struct HBRouterMethodOptions: OptionSet, HBSendable {
    public let rawValue: Int
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// don't collate the request body, all handler to stream it
    public static var streamBody: HBRouterMethodOptions = .init(rawValue: 1 << 0)
    /// allow handler to edit response via `request.response`
    public static var editResponse: HBRouterMethodOptions = .init(rawValue: 1 << 1)
}

public protocol HBRouterMethods {
    typealias Handler<Output> = (HBRequest) throws -> Output
    typealias FutureHandler<Output> = (HBRequest) -> EventLoopFuture<Output>

    /// Add path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult func on<Output: HBResponseGenerator>(
        _ path: String,
        method: HTTPMethod,
        options: HBRouterMethodOptions,
        use: @escaping Handler<Output>
    ) -> Self

    /// Add path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult func on<Output: HBResponseGenerator>(
        _ path: String,
        method: HTTPMethod,
        options: HBRouterMethodOptions,
        use: @escaping FutureHandler<Output>
    ) -> Self

    #if compiler(>=5.5) && canImport(_Concurrency)

    typealias AsyncHandler<Output> = @Sendable (HBRequest) async throws -> Output

    /// Add path for async closure
    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @discardableResult func on<Output: HBResponseGenerator>(
        _ path: String,
        method: HTTPMethod,
        options: HBRouterMethodOptions,
        use: @escaping AsyncHandler<Output>
    ) -> Self
    #endif // compiler(>=5.5) && canImport(_Concurrency)

    /// add group
    func group(_ path: String) -> HBRouterGroup
}

extension HBRouterMethods {
    /// GET path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func get<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping Handler<Output>
    ) -> Self {
        return on(path, method: .GET, options: options, use: handler)
    }

    /// PUT path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func put<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping Handler<Output>
    ) -> Self {
        return on(path, method: .PUT, options: options, use: handler)
    }

    /// POST path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func post<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping Handler<Output>
    ) -> Self {
        return on(path, method: .POST, options: options, use: handler)
    }

    /// HEAD path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func head<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping Handler<Output>
    ) -> Self {
        return on(path, method: .HEAD, options: options, use: handler)
    }

    /// DELETE path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func delete<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping Handler<Output>
    ) -> Self {
        return on(path, method: .DELETE, options: options, use: handler)
    }

    /// PATCH path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func patch<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping Handler<Output>
    ) -> Self {
        return on(path, method: .PATCH, options: options, use: handler)
    }

    /// GET path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func get<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping FutureHandler<Output>
    ) -> Self {
        return on(path, method: .GET, options: options, use: handler)
    }

    /// PUT path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func put<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping FutureHandler<Output>
    ) -> Self {
        return on(path, method: .PUT, options: options, use: handler)
    }

    /// POST path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func delete<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping FutureHandler<Output>
    ) -> Self {
        return on(path, method: .DELETE, options: options, use: handler)
    }

    /// HEAD path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func head<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping FutureHandler<Output>
    ) -> Self {
        return on(path, method: .HEAD, options: options, use: handler)
    }

    /// DELETE path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func post<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping FutureHandler<Output>
    ) -> Self {
        return on(path, method: .POST, options: options, use: handler)
    }

    /// PATCH path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func patch<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping FutureHandler<Output>
    ) -> Self {
        return on(path, method: .PATCH, options: options, use: handler)
    }
}

extension HBRouterMethods {
    // generate response from request. Moved repeated code into private function
    private static func respond<Output: HBResponseGenerator>(
        request: HBRequest,
        options: HBRouterMethodOptions,
        use closure: @escaping Handler<Output>
    ) throws -> HBResponse {
        let response: HBResponse
        if options.contains(.editResponse) {
            var request = request
            request.response = .init()
            response = try closure(request).patchedResponse(from: request)
        } else {
            response = try closure(request).response(from: request)
        }
        return response
    }

    func constructResponder<Output: HBResponseGenerator>(
        options: HBRouterMethodOptions,
        use closure: @escaping Handler<Output>
    ) -> HBResponder {
        if options.contains(.streamBody) {
            return HBCallbackResponder { request in
                do {
                    let response = try Self.respond(request: request, options: options, use: closure)
                    return request.success(response)
                } catch {
                    return request.failure(error)
                }
            }
        } else {
            return HBCallbackResponder { request in
                if case .byteBuffer = request.body {
                    do {
                        let response = try Self.respond(request: request, options: options, use: closure)
                        return request.success(response)
                    } catch {
                        return request.failure(error)
                    }
                } else {
                    return request.body.consumeBody(on: request.eventLoop).flatMapThrowing { buffer in
                        var request = request
                        request.body = .byteBuffer(buffer)
                        return try Self.respond(request: request, options: options, use: closure)
                    }
                }
            }
        }
    }

    // generate response from request. Moved repeated code into internal function
    private static func respond<Output: HBResponseGenerator>(
        request: HBRequest,
        options: HBRouterMethodOptions,
        use closure: @escaping FutureHandler<Output>
    ) -> EventLoopFuture<HBResponse> {
        var request = request
        let responseFuture: EventLoopFuture<HBResponse>
        if options.contains(.editResponse) {
            request.response = .init()
            responseFuture = closure(request).flatMapThrowing { try $0.patchedResponse(from: request) }
        } else {
            responseFuture = closure(request).flatMapThrowing { try $0.response(from: request) }
        }
        return responseFuture.hop(to: request.eventLoop)
    }

    func constructResponder<Output: HBResponseGenerator>(
        options: HBRouterMethodOptions,
        use closure: @escaping FutureHandler<Output>
    ) -> HBResponder {
        if options.contains(.streamBody) {
            return HBCallbackResponder { request in
                return Self.respond(request: request, options: options, use: closure)
            }
        } else {
            return HBCallbackResponder { request in
                var request = request
                if case .byteBuffer = request.body {
                    return Self.respond(request: request, options: options, use: closure)
                } else {
                    return request.body.consumeBody(on: request.eventLoop).flatMap { buffer in
                        request.body = .byteBuffer(buffer)
                        return Self.respond(request: request, options: options, use: closure)
                    }
                }
            }
        }
    }
}
