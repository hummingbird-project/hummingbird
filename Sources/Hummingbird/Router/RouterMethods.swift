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

public struct HBRouterMethodOptions: OptionSet {
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
    /// Add path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult func on<Output: HBResponseGenerator>(
        _ path: String,
        method: HTTPMethod,
        options: HBRouterMethodOptions,
        use: @escaping (HBRequest) throws -> Output
    ) -> Self

    /// Add path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult func on<Output: HBResponseGenerator>(
        _ path: String,
        method: HTTPMethod,
        options: HBRouterMethodOptions,
        use: @escaping (HBRequest) -> EventLoopFuture<Output>
    ) -> Self

    #if compiler(>=5.5)
    /// Add path for async closure
    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    @discardableResult func on<Output: HBResponseGenerator>(
        _ path: String,
        method: HTTPMethod,
        options: HBRouterMethodOptions,
        use: @escaping (HBRequest) async throws -> Output
    ) -> Self
    #endif // compiler(>=5.5)

    /// add group
    func group(_ path: String) -> HBRouterGroup
}

extension HBRouterMethods {
    /// GET path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func get<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping (HBRequest) throws -> Output
    ) -> Self {
        return on(path, method: .GET, options: options, use: handler)
    }

    /// PUT path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func put<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping (HBRequest) throws -> Output
    ) -> Self {
        return on(path, method: .PUT, options: options, use: handler)
    }

    /// POST path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func post<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping (HBRequest) throws -> Output
    ) -> Self {
        return on(path, method: .POST, options: options, use: handler)
    }

    /// HEAD path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func head<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping (HBRequest) throws -> Output
    ) -> Self {
        return on(path, method: .HEAD, options: options, use: handler)
    }

    /// DELETE path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func delete<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping (HBRequest) throws -> Output
    ) -> Self {
        return on(path, method: .DELETE, options: options, use: handler)
    }

    /// PATCH path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func patch<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping (HBRequest) throws -> Output
    ) -> Self {
        return on(path, method: .PATCH, options: options, use: handler)
    }

    /// GET path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func get<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping (HBRequest) -> EventLoopFuture<Output>
    ) -> Self {
        return on(path, method: .GET, options: options, use: handler)
    }

    /// PUT path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func put<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping (HBRequest) -> EventLoopFuture<Output>
    ) -> Self {
        return on(path, method: .PUT, options: options, use: handler)
    }

    /// POST path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func delete<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping (HBRequest) -> EventLoopFuture<Output>
    ) -> Self {
        return on(path, method: .DELETE, options: options, use: handler)
    }

    /// HEAD path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func head<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping (HBRequest) -> EventLoopFuture<Output>
    ) -> Self {
        return on(path, method: .HEAD, options: options, use: handler)
    }

    /// DELETE path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func post<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping (HBRequest) -> EventLoopFuture<Output>
    ) -> Self {
        return on(path, method: .POST, options: options, use: handler)
    }

    /// PATCH path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func patch<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping (HBRequest) -> EventLoopFuture<Output>
    ) -> Self {
        return on(path, method: .PATCH, options: options, use: handler)
    }
}

extension HBRouterMethods {
    func constructResponder<Output: HBResponseGenerator>(
        options: HBRouterMethodOptions,
        use closure: @escaping (HBRequest) throws -> Output
    ) -> HBResponder {
        if options.contains(.streamBody) {
            return HBCallbackResponder { request in
                var request = request
                if options.contains(.editResponse) {
                    request.response = .init()
                }
                do {
                    let response = try closure(request).patchedResponse(from: request)
                    return request.success(response)
                } catch {
                    return request.failure(error)
                }
            }
        } else {
            return HBCallbackResponder { request in
                var request = request
                if options.contains(.editResponse) {
                    request.response = .init()
                }
                if case .byteBuffer = request.body {
                    do {
                        let response = try closure(request).patchedResponse(from: request)
                        return request.success(response)
                    } catch {
                        return request.failure(error)
                    }
                } else {
                    return request.body.consumeBody(on: request.eventLoop).flatMapThrowing { buffer in
                        request.body = .byteBuffer(buffer)
                        return try closure(request).patchedResponse(from: request)
                    }
                }
            }
        }
    }

    func constructResponder<Output: HBResponseGenerator>(
        options: HBRouterMethodOptions,
        use closure: @escaping (HBRequest) -> EventLoopFuture<Output>
    ) -> HBResponder {
        if options.contains(.streamBody) {
            return HBCallbackResponder { request in
                var request = request
                if options.contains(.editResponse) {
                    request.response = .init()
                }
                return closure(request).flatMapThrowing { try $0.patchedResponse(from: request) }
                    .hop(to: request.eventLoop)
            }
        } else {
            return HBCallbackResponder { request in
                var request = request
                if options.contains(.editResponse) {
                    request.response = .init()
                }
                if case .byteBuffer = request.body {
                    return closure(request).flatMapThrowing { try $0.patchedResponse(from: request) }
                        .hop(to: request.eventLoop)
                } else {
                    return request.body.consumeBody(on: request.eventLoop).flatMap { buffer in
                        request.body = .byteBuffer(buffer)
                        return closure(request).flatMapThrowing { try $0.patchedResponse(from: request) }
                            .hop(to: request.eventLoop)
                    }
                }
            }
        }
    }
}
