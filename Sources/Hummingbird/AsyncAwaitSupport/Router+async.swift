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

#if compiler(>=5.5.2) && canImport(_Concurrency)

import NIOCore

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension HBRouterMethods {
    /// GET path for async closure returning type conforming to ResponseEncodable
    @discardableResult public func get<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping (HBRequest) async throws -> Output
    ) -> Self {
        return on(path, method: .GET, options: options, use: handler)
    }

    /// PUT path for async closure returning type conforming to ResponseEncodable
    @discardableResult public func put<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping (HBRequest) async throws -> Output
    ) -> Self {
        return on(path, method: .PUT, options: options, use: handler)
    }

    /// DELETE path for async closure returning type conforming to ResponseEncodable
    @discardableResult public func delete<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping (HBRequest) async throws -> Output
    ) -> Self {
        return on(path, method: .DELETE, options: options, use: handler)
    }

    /// HEAD path for async closure returning type conforming to ResponseEncodable
    @discardableResult public func head<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping (HBRequest) async throws -> Output
    ) -> Self {
        return on(path, method: .HEAD, options: options, use: handler)
    }

    /// POST path for async closure returning type conforming to ResponseEncodable
    @discardableResult public func post<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping (HBRequest) async throws -> Output
    ) -> Self {
        return on(path, method: .POST, options: options, use: handler)
    }

    /// PATCH path for async closure returning type conforming to ResponseEncodable
    @discardableResult public func patch<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping (HBRequest) async throws -> Output
    ) -> Self {
        return on(path, method: .PATCH, options: options, use: handler)
    }

    func constructResponder<Output: HBResponseGenerator>(
        options: HBRouterMethodOptions = [],
        use closure: @escaping (HBRequest) async throws -> Output
    ) -> HBResponder {
        return HBAsyncCallbackResponder { request in
            var request = request
            if case .stream = request.body, !options.contains(.streamBody) {
                let buffer = try await request.body.consumeBody(
                    maxSize: request.application.configuration.maxUploadSize
                )
                request.body = .byteBuffer(buffer)
            }
            if options.contains(.editResponse) {
                request.response = .init()
                return try await closure(request).patchedResponse(from: request)
            } else {
                return try await closure(request).response(from: request)
            }
        }
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension HBRouterBuilder {
    /// Add path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func on<Output: HBResponseGenerator>(
        _ path: String,
        method: HTTPMethod,
        options: HBRouterMethodOptions = [],
        use closure: @escaping (HBRequest) async throws -> Output
    ) -> Self {
        let responder = constructResponder(options: options, use: closure)
        add(path, method: method, responder: responder)
        return self
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension HBRouterGroup {
    /// Add path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func on<Output: HBResponseGenerator>(
        _ path: String = "",
        method: HTTPMethod,
        options: HBRouterMethodOptions = [],
        use closure: @escaping (HBRequest) async throws -> Output
    ) -> Self {
        let responder = constructResponder(options: options, use: closure)
        let path = self.combinePaths(self.path, path)
        self.router.add(path, method: method, responder: self.middlewares.constructResponder(finalResponder: responder))
        return self
    }
}

#endif // compiler(>=5.5) && canImport(_Concurrency)
