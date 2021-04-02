
public protocol HBRequestHandler: Decodable {
    associatedtype Output
    init(from: HBRequest) throws
    func handle(request: HBRequest) throws -> Output
}

extension HBRequestHandler {
    public init(from request: HBRequest) throws {
        self = try request.application.decoder.decode(Self.self, from: request)
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
        return on(path, method: method, body: body) { request -> Output in
            let handler: Handler
            do {
                handler = try Handler.init(from: request)
            } catch {
                request.logger.debug("Decode Error: \(error)")
                throw HBHTTPError(.badRequest)
            }
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
        return on(path, method: method, body: body) { request -> EventLoopFuture<Output> in
            let handler: Handler
            do {
                handler = try Handler.init(from: request)
            } catch {
                request.logger.debug("Decode Error: \(error)")
                return request.failure(.badRequest)
            }
            do {
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
        return on(path, method: .GET, body: body, use: handler)
    }

    /// PUT path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func put<Handler: HBRequestHandler, Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: Handler.Type
    ) -> Self where Handler.Output == Output {
        return on(path, method: .PUT, body: body, use: handler)
    }

    /// POST path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func post<Handler: HBRequestHandler, Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: Handler.Type
    ) -> Self where Handler.Output == Output {
        return on(path, method: .POST, body: body, use: handler)
    }

    /// HEAD path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func head<Handler: HBRequestHandler, Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: Handler.Type
    ) -> Self where Handler.Output == Output {
        return on(path, method: .HEAD, body: body, use: handler)
    }

    /// DELETE path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func delete<Handler: HBRequestHandler, Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: Handler.Type
    ) -> Self where Handler.Output == Output {
        return on(path, method: .DELETE, body: body, use: handler)
    }

    /// PATCH path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func patch<Handler: HBRequestHandler, Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: Handler.Type
    ) -> Self where Handler.Output == Output {
        return on(path, method: .PATCH, body: body, use: handler)
    }

    /// GET path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func get<Handler: HBRequestHandler, Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: Handler.Type
    ) -> Self where Handler.Output == EventLoopFuture<Output> {
        return on(path, method: .GET, body: body, use: handler)
    }

    /// PUT path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func put<Handler: HBRequestHandler, Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: Handler.Type
    ) -> Self where Handler.Output == EventLoopFuture<Output> {
        return on(path, method: .PUT, body: body, use: handler)
    }

    /// POST path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func post<Handler: HBRequestHandler, Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: Handler.Type
    ) -> Self where Handler.Output == EventLoopFuture<Output> {
        return on(path, method: .POST, body: body, use: handler)
    }

    /// HEAD path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func head<Handler: HBRequestHandler, Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: Handler.Type
    ) -> Self where Handler.Output == EventLoopFuture<Output> {
        return on(path, method: .HEAD, body: body, use: handler)
    }

    /// DELETE path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func delete<Handler: HBRequestHandler, Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: Handler.Type
    ) -> Self where Handler.Output == EventLoopFuture<Output> {
        return on(path, method: .DELETE, body: body, use: handler)
    }

    /// PATCH path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func patch<Handler: HBRequestHandler, Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: Handler.Type
    ) -> Self where Handler.Output == EventLoopFuture<Output> {
        return on(path, method: .PATCH, body: body, use: handler)
    }}
