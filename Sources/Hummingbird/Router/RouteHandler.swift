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

import HTTPTypes

/// Object for handling requests.
///
/// Instead of passing a closure to the router you can provide an object it should try and
/// create before handling the request. This allows you to separate the extraction of data
/// from the request and the processing of the request. For example
/// ```
/// struct UpdateReminder: RouteHandler {
///     struct Request: Codable {
///         let description: String
///         let date: Date
///     }
///     let update: Request
///     let id: String
///
///     init(from request: Request, context: some BaseRequestContext) throws {
///         self.update = try await request.decode(as: Request.self, context: context)
///         self.id = try request.parameters.require("id")
///     }
///     func handle(context: some BaseRequestContext) async throws -> HTTPResponse.Status {
///         let reminder = Reminder(id: id, update: update)
///         return reminder.update(on: db)
///             .map { _ in .ok }
///     }
/// }
/// ```
public protocol RouteHandler {
    associatedtype Output
    init(from: Request, context: some BaseRequestContext) async throws
    func handle(context: some BaseRequestContext) async throws -> Output
}

extension RouterMethods {
    /// Add path for `RouteHandler` that returns a value conforming to `ResponseGenerator`
    @discardableResult public func on<Handler: RouteHandler, Output: ResponseGenerator>(
        _ path: String,
        method: HTTPRequest.Method,
        use handlerType: Handler.Type
    ) -> Self where Handler.Output == Output {
        return self.on(path, method: method) { request, context -> Output in
            let handler = try await Handler(from: request, context: context)
            return try await handler.handle(context: context)
        }
    }

    /// GET path for closure returning type conforming to ResponseGenerator
    @discardableResult public func get<Handler: RouteHandler, Output: ResponseGenerator>(
        _ path: String = "",
        use handler: Handler.Type
    ) -> Self where Handler.Output == Output {
        return self.on(path, method: .get, use: handler)
    }

    /// PUT path for closure returning type conforming to ResponseGenerator
    @discardableResult public func put<Handler: RouteHandler, Output: ResponseGenerator>(
        _ path: String = "",
        use handler: Handler.Type
    ) -> Self where Handler.Output == Output {
        return self.on(path, method: .put, use: handler)
    }

    /// POST path for closure returning type conforming to ResponseGenerator
    @discardableResult public func post<Handler: RouteHandler, Output: ResponseGenerator>(
        _ path: String = "",
        use handler: Handler.Type
    ) -> Self where Handler.Output == Output {
        return self.on(path, method: .post, use: handler)
    }

    /// HEAD path for closure returning type conforming to ResponseGenerator
    @discardableResult public func head<Handler: RouteHandler, Output: ResponseGenerator>(
        _ path: String = "",
        use handler: Handler.Type
    ) -> Self where Handler.Output == Output {
        return self.on(path, method: .head, use: handler)
    }

    /// DELETE path for closure returning type conforming to ResponseGenerator
    @discardableResult public func delete<Handler: RouteHandler, Output: ResponseGenerator>(
        _ path: String = "",
        use handler: Handler.Type
    ) -> Self where Handler.Output == Output {
        return self.on(path, method: .delete, use: handler)
    }

    /// PATCH path for closure returning type conforming to ResponseGenerator
    @discardableResult public func patch<Handler: RouteHandler, Output: ResponseGenerator>(
        _ path: String = "",
        use handler: Handler.Type
    ) -> Self where Handler.Output == Output {
        return self.on(path, method: .patch, use: handler)
    }
}
