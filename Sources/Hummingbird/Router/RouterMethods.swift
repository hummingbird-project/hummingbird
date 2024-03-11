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

import HTTPTypes
import NIOCore

/// Conform to `RouterMethods` to add standard router verb (get, post ...) methods
public protocol RouterMethods<Context> {
    associatedtype Context: BaseRequestContext

    /// Add path for async closure
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    @discardableResult func on<Output: ResponseGenerator>(
        _ path: String,
        method: HTTPRequest.Method,
        use: @Sendable @escaping (Request, Context) async throws -> Output
    ) -> Self

    /// add group
    func group(_ path: String) -> RouterGroup<Context>
}

extension RouterMethods {
    /// GET path for async closure returning type conforming to ResponseGenerator
    @discardableResult public func get(
        _ path: String = "",
        use handler: @Sendable @escaping (Request, Context) async throws -> some ResponseGenerator
    ) -> Self {
        return on(path, method: .get, use: handler)
    }

    /// PUT path for async closure returning type conforming to ResponseGenerator
    @discardableResult public func put(
        _ path: String = "",
        use handler: @Sendable @escaping (Request, Context) async throws -> some ResponseGenerator
    ) -> Self {
        return on(path, method: .put, use: handler)
    }

    /// DELETE path for async closure returning type conforming to ResponseGenerator
    @discardableResult public func delete(
        _ path: String = "",
        use handler: @Sendable @escaping (Request, Context) async throws -> some ResponseGenerator
    ) -> Self {
        return on(path, method: .delete, use: handler)
    }

    /// HEAD path for async closure returning type conforming to ResponseGenerator
    @discardableResult public func head(
        _ path: String = "",
        use handler: @Sendable @escaping (Request, Context) async throws -> some ResponseGenerator
    ) -> Self {
        return on(path, method: .head, use: handler)
    }

    /// POST path for async closure returning type conforming to ResponseGenerator
    @discardableResult public func post(
        _ path: String = "",
        use handler: @Sendable @escaping (Request, Context) async throws -> some ResponseGenerator
    ) -> Self {
        return on(path, method: .post, use: handler)
    }

    /// PATCH path for async closure returning type conforming to ResponseGenerator
    @discardableResult public func patch(
        _ path: String = "",
        use handler: @Sendable @escaping (Request, Context) async throws -> some ResponseGenerator
    ) -> Self {
        return on(path, method: .patch, use: handler)
    }

    func constructResponder(
        use closure: @Sendable @escaping (Request, Context) async throws -> some ResponseGenerator
    ) -> CallbackResponder<Context> {
        return CallbackResponder { request, context in
            let output = try await closure(request, context)
            return try output.response(from: request, context: context)
        }
    }
}
