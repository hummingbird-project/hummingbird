import NIO
import NIOHTTP1


public enum HBBodyCollation {
    case collate
    case stream
}

public protocol HBRouterMethods {
    /// Add path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult func on<Output: HBResponseGenerator>(
        _ path: String,
        method: HTTPMethod,
        body: HBBodyCollation,
        use: @escaping (HBRequest) throws -> Output
    ) -> Self

    /// Add path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult func on<Output: HBResponseFutureGenerator>(
        _ path: String,
        method: HTTPMethod,
        body: HBBodyCollation,
        use: @escaping (HBRequest) -> Output
    ) -> Self
}

extension HBRouterMethods {
    /// GET path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func get<Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: @escaping (HBRequest) throws -> Output
    ) -> Self {
        return on(path, method: .GET, body: body, use: handler)
    }

    /// PUT path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func put<Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: @escaping (HBRequest) throws -> Output
    ) -> Self {
        return on(path, method: .PUT, body: body, use: handler)
    }

    /// POST path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func post<Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: @escaping (HBRequest) throws -> Output
    ) -> Self {
        return on(path, method: .POST, body: body, use: handler)
    }

    /// HEAD path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func head<Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: @escaping (HBRequest) throws -> Output
    ) -> Self {
        return on(path, method: .HEAD, body: body, use: handler)
    }

    /// DELETE path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func delete<Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: @escaping (HBRequest) throws -> Output
    ) -> Self {
        return on(path, method: .DELETE, body: body, use: handler)
    }

    /// PATCH path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func patch<Output: HBResponseGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: @escaping (HBRequest) throws -> Output
    ) -> Self {
        return on(path, method: .PATCH, body: body, use: handler)
    }

    /// GET path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func get<Output: HBResponseFutureGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: @escaping (HBRequest) -> Output
    ) -> Self {
        return on(path, method: .GET, body: body, use: handler)
    }

    /// PUT path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func put<Output: HBResponseFutureGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: @escaping (HBRequest) -> Output
    ) -> Self {
        return on(path, method: .PUT, body: body, use: handler)
    }

    /// POST path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func delete<Output: HBResponseFutureGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: @escaping (HBRequest) -> Output
    ) -> Self {
        return on(path, method: .DELETE, body: body, use: handler)
    }

    /// HEAD path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func head<Output: HBResponseFutureGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: @escaping (HBRequest) -> Output
    ) -> Self {
        return on(path, method: .HEAD, body: body, use: handler)
    }

    /// DELETE path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func post<Output: HBResponseFutureGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: @escaping (HBRequest) -> Output
    ) -> Self {
        return on(path, method: .POST, body: body, use: handler)
    }

    /// PATCH path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func patch<Output: HBResponseFutureGenerator>(
        _ path: String = "",
        body: HBBodyCollation = .collate,
        use handler: @escaping (HBRequest) -> Output
    ) -> Self {
        return on(path, method: .PATCH, body: body, use: handler)
    }
}
