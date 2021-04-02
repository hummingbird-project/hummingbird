/// Object for handling requests.
///
/// Instead of passing a closure to the router you can provide an object it should try and
/// create before handling the request
public protocol HBRequestHandler {
    associatedtype Output
    init(from: HBRequest) throws
    func handle(request: HBRequest) throws -> Output
}

/// `HBRequestHandler` which uses `Codable` to initialize it
///
/// An example
/// ```
/// struct CreateUser: HBRequestDecodable {
///     let username: String
///     let password: String
///     func handle(request: HBRequest) -> EventLoopFuture<HTTPResponseStatus> {
///         return addUserToDatabase(
///             name: self.username,
///             password: self.password
///         ).map { _ in .ok }
/// }
/// application.router.put("user", use: CreateUser.self)
///
public protocol HBRequestDecodable: HBRequestHandler, Decodable {}

extension HBRequestDecodable {
    /// Create using `Codable` interfaces
    /// - Parameter request: request
    /// - Throws: HBHTTPError
    public init(from request: HBRequest) throws {
        do {
            self = try request.application.decoder.decode(Self.self, from: request)
        } catch {
            request.logger.debug("Decode Error: \(error)")
            throw HBHTTPError(.badRequest)
        }
    }
}

extension HBRouterMethods {
    /// Add path for `HBRouteHandler` that returns a value conforming to `HBResponseGenerator`
    @discardableResult public func on<Handler: HBRequestHandler, Output: HBResponseGenerator>(
        _ path: String,
        method: HTTPMethod,
        body: HBBodyCollation = .collate,
        use handlerType: Handler.Type
    ) -> Self where Handler.Output == Output {
        return self.on(path, method: method, body: body) { request -> Output in
            let handler = try Handler(from: request)
            return try handler.handle(request: request)
        }
    }

    /// Add path for `HBRouteHandler` that returns an `EventLoopFuture` specialized with a type conforming
    /// to `HBResponseGenerator`
    @discardableResult func on<Handler: HBRequestHandler, Output: HBResponseGenerator>(
        _ path: String,
        method: HTTPMethod,
        body: HBBodyCollation = .collate,
        use handlerType: Handler.Type
    ) -> Self where Handler.Output == EventLoopFuture<Output> {
        return self.on(path, method: method, body: body) { request -> EventLoopFuture<Output> in
            do {
                let handler = try Handler(from: request)
                return try handler.handle(request: request)
            } catch {
                return request.failure(error)
            }
        }
    }

    /// GET path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func get<Handler: HBRequestHandler, Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: Handler.Type
    ) -> Self where Handler.Output == Output {
        return self.on(path, method: .GET, body: body, use: handler)
    }

    /// PUT path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func put<Handler: HBRequestHandler, Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: Handler.Type
    ) -> Self where Handler.Output == Output {
        return self.on(path, method: .PUT, body: body, use: handler)
    }

    /// POST path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func post<Handler: HBRequestHandler, Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: Handler.Type
    ) -> Self where Handler.Output == Output {
        return self.on(path, method: .POST, body: body, use: handler)
    }

    /// HEAD path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func head<Handler: HBRequestHandler, Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: Handler.Type
    ) -> Self where Handler.Output == Output {
        return self.on(path, method: .HEAD, body: body, use: handler)
    }

    /// DELETE path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func delete<Handler: HBRequestHandler, Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: Handler.Type
    ) -> Self where Handler.Output == Output {
        return self.on(path, method: .DELETE, body: body, use: handler)
    }

    /// PATCH path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func patch<Handler: HBRequestHandler, Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: Handler.Type
    ) -> Self where Handler.Output == Output {
        return self.on(path, method: .PATCH, body: body, use: handler)
    }

    /// GET path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func get<Handler: HBRequestHandler, Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: Handler.Type
    ) -> Self where Handler.Output == EventLoopFuture<Output> {
        return self.on(path, method: .GET, body: body, use: handler)
    }

    /// PUT path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func put<Handler: HBRequestHandler, Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: Handler.Type
    ) -> Self where Handler.Output == EventLoopFuture<Output> {
        return self.on(path, method: .PUT, body: body, use: handler)
    }

    /// POST path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func post<Handler: HBRequestHandler, Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: Handler.Type
    ) -> Self where Handler.Output == EventLoopFuture<Output> {
        return self.on(path, method: .POST, body: body, use: handler)
    }

    /// HEAD path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func head<Handler: HBRequestHandler, Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: Handler.Type
    ) -> Self where Handler.Output == EventLoopFuture<Output> {
        return self.on(path, method: .HEAD, body: body, use: handler)
    }

    /// DELETE path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func delete<Handler: HBRequestHandler, Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: Handler.Type
    ) -> Self where Handler.Output == EventLoopFuture<Output> {
        return self.on(path, method: .DELETE, body: body, use: handler)
    }

    /// PATCH path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func patch<Handler: HBRequestHandler, Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: Handler.Type
    ) -> Self where Handler.Output == EventLoopFuture<Output> {
        return self.on(path, method: .PATCH, body: body, use: handler)
    }
}
