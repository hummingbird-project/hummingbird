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

#if compiler(>=5.5)

import _NIOConcurrency

@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
extension HBRouterMethods {
    /// GET path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func get<Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: @escaping (HBRequest) async throws -> Output
    ) -> Self {
        return on(path, method: .GET, body: body, use: handler)
    }

    /// PUT path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func put<Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: @escaping (HBRequest) async throws -> Output
    ) -> Self {
        return on(path, method: .PUT, body: body, use: handler)
    }

    /// POST path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func delete<Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: @escaping (HBRequest) async throws -> Output
    ) -> Self {
        return on(path, method: .DELETE, body: body, use: handler)
    }

    /// HEAD path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func head<Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: @escaping (HBRequest) async throws -> Output
    ) -> Self {
        return on(path, method: .HEAD, body: body, use: handler)
    }

    /// DELETE path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func post<Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: @escaping (HBRequest) async throws -> Output
    ) -> Self {
        return on(path, method: .POST, body: body, use: handler)
    }

    /// PATCH path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func patch<Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: @escaping (HBRequest) async throws -> Output
    ) -> Self {
        return on(path, method: .PATCH, body: body, use: handler)
    }

    func constructResponder<Output: HBResponseGenerator>(
        body: HBBodyCollation,
        use closure: @escaping (HBRequest) async throws -> Output
    ) -> HBResponder {
        switch body {
        case .collate:
            return HBAsyncCallbackResponder { request in
                if case .byteBuffer = request.body {
                    do {
                        let response = try await closure(request).response(from: request).apply(patch: request.optionalResponse)
                        return response
                    }
                } else {
                    let buffer = try await request.body.consumeBody(on: request.eventLoop).get()
                    request.body = .byteBuffer(buffer)
                    let response = try await closure(request).response(from: request).apply(patch: request.optionalResponse)
                    return response
                }
            }
        case .stream:
            return HBAsyncCallbackResponder { request in
                let response = try await closure(request).response(from: request).apply(patch: request.optionalResponse)
                return response
            }
        }
    }
}

@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
extension HBRouter {
    /// Add path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func on<Output: HBResponseGenerator>(
        _ path: String,
        method: HTTPMethod,
        body: HBBodyCollation = .collate,
        use closure: @escaping (HBRequest) async throws -> Output
    ) -> Self {
        let responder = constructResponder(body: body, use: closure)
        add(path, method: method, responder: responder)
        return self
    }
}

@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
extension HBRouterGroup {
    /// Add path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func on<Output: HBResponseGenerator>(
        _ path: String = "",
        method: HTTPMethod,
        body: HBBodyCollation = .collate,
        use closure: @escaping (HBRequest) async throws -> Output
    ) -> Self {
        let responder = constructResponder(body: body, use: closure)
        let path = self.combinePaths(self.path, path)
        self.router.add(path, method: method, responder: self.middlewares.constructResponder(finalResponder: responder))
        return self
    }
}

#endif // compiler(>=5.5)
