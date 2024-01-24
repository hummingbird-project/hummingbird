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
/// struct UpdateReminder: HBRouteHandler {
///     struct Request: Codable {
///         let description: String
///         let date: Date
///     }
///     let update: Request
///     let id: String
///
///     init(from request: HBRequest, context: some HBBaseRequestContext) throws {
///         self.update = try await request.decode(as: Request.self, context: context)
///         self.id = try request.parameters.require("id")
///     }
///     func handle(context: some HBBaseRequestContext) async throws -> HTTPResponse.Status {
///         let reminder = Reminder(id: id, update: update)
///         return reminder.update(on: db)
///             .map { _ in .ok }
///     }
/// }
/// ```
public protocol HBRouteHandler {
    associatedtype Output
    init(from: HBRequest, context: some HBBaseRequestContext) async throws
    func handle(context: some HBBaseRequestContext) async throws -> Output
}

extension HBRouterMethods {
    /// Add path for `HBRouteHandler` that returns a value conforming to `HBResponseGenerator`
    @discardableResult public func on<Handler: HBRouteHandler, Output: HBResponseGenerator>(
        _ path: String,
        method: HTTPRequest.Method,
        use handlerType: Handler.Type
    ) -> Self where Handler.Output == Output {
        return self.on(path, method: method) { request, context -> Output in
            let handler = try await Handler(from: request, context: context)
            return try await handler.handle(context: context)
        }
    }

    /// GET path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func get<Handler: HBRouteHandler, Output: HBResponseGenerator>(
        _ path: String = "",
        use handler: Handler.Type
    ) -> Self where Handler.Output == Output {
        return self.on(path, method: .get, use: handler)
    }

    /// PUT path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func put<Handler: HBRouteHandler, Output: HBResponseGenerator>(
        _ path: String = "",
        use handler: Handler.Type
    ) -> Self where Handler.Output == Output {
        return self.on(path, method: .put, use: handler)
    }

    /// POST path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func post<Handler: HBRouteHandler, Output: HBResponseGenerator>(
        _ path: String = "",
        use handler: Handler.Type
    ) -> Self where Handler.Output == Output {
        return self.on(path, method: .post, use: handler)
    }

    /// HEAD path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func head<Handler: HBRouteHandler, Output: HBResponseGenerator>(
        _ path: String = "",
        use handler: Handler.Type
    ) -> Self where Handler.Output == Output {
        return self.on(path, method: .head, use: handler)
    }

    /// DELETE path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func delete<Handler: HBRouteHandler, Output: HBResponseGenerator>(
        _ path: String = "",
        use handler: Handler.Type
    ) -> Self where Handler.Output == Output {
        return self.on(path, method: .delete, use: handler)
    }

    /// PATCH path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func patch<Handler: HBRouteHandler, Output: HBResponseGenerator>(
        _ path: String = "",
        use handler: Handler.Type
    ) -> Self where Handler.Output == Output {
        return self.on(path, method: .patch, use: handler)
    }
}
