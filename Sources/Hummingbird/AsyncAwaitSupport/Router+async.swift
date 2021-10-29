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

#if compiler(>=5.5) && canImport(_Concurrency)

import NIOCore

@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
extension HBRouterMethods {
    /// GET path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func get<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping AsyncHandler<Output>
    ) -> Self {
        return on(path, method: .GET, options: options, use: handler)
    }

    /// PUT path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func put<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping AsyncHandler<Output>
    ) -> Self {
        return on(path, method: .PUT, options: options, use: handler)
    }

    /// POST path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func delete<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping AsyncHandler<Output>
    ) -> Self {
        return on(path, method: .DELETE, options: options, use: handler)
    }

    /// HEAD path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func head<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping AsyncHandler<Output>
    ) -> Self {
        return on(path, method: .HEAD, options: options, use: handler)
    }

    /// DELETE path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func post<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping AsyncHandler<Output>
    ) -> Self {
        return on(path, method: .POST, options: options, use: handler)
    }

    /// PATCH path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func patch<Output: HBResponseGenerator>(
        _ path: String = "",
        options: HBRouterMethodOptions = [],
        use handler: @escaping AsyncHandler<Output>
    ) -> Self {
        return on(path, method: .PATCH, options: options, use: handler)
    }

    func constructResponder<Output: HBResponseGenerator>(
        options: HBRouterMethodOptions = [],
        use closure: @escaping AsyncHandler<Output>
    ) -> HBResponder {
        return HBAsyncCallbackResponder { request in
            var request = request
            if case .stream = request.body, !options.contains(.streamBody) {
                let buffer = try await request.body.consumeBody(on: request.eventLoop).get()
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

@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
extension HBRouter {
    /// Add path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func on<Output: HBResponseGenerator>(
        _ path: String,
        method: HTTPMethod,
        options: HBRouterMethodOptions = [],
        use closure: @escaping AsyncHandler<Output>
    ) -> Self {
        let responder = constructResponder(options: options, use: closure)
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
        options: HBRouterMethodOptions = [],
        use closure: @escaping AsyncHandler<Output>
    ) -> Self {
        let responder = constructResponder(options: options, use: closure)
        let path = self.combinePaths(self.path, path)
        self.router.add(path, method: method, responder: self.middlewares.constructResponder(finalResponder: responder))
        return self
    }
}

#endif // compiler(>=5.5) && canImport(_Concurrency)
