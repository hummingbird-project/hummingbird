import NIO
import NIOHTTP1

public protocol HBRouterMethods {
    /// Add path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult func add<R: HBResponseGenerator>(_ path: String, method: HTTPMethod, use: @escaping (HBRequest) throws -> R) -> Self
    /// Add path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult func add<R: HBResponseFutureGenerator>(_ path: String, method: HTTPMethod, use: @escaping (HBRequest) -> R) -> Self
}

extension HBRouterMethods {
    /// GET path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func get<R: HBResponseGenerator>(_ path: String = "", use closure: @escaping (HBRequest) throws -> R) -> Self {
        return add(path, method: .GET, use: closure)
    }

    /// PUT path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func put<R: HBResponseGenerator>(_ path: String = "", use closure: @escaping (HBRequest) throws -> R) -> Self {
        return add(path, method: .PUT, use: closure)
    }

    /// POST path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func post<R: HBResponseGenerator>(_ path: String = "", use closure: @escaping (HBRequest) throws -> R) -> Self {
        return add(path, method: .POST, use: closure)
    }

    /// DELETE path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func delete<R: HBResponseGenerator>(_ path: String = "", use closure: @escaping (HBRequest) throws -> R) -> Self {
        return add(path, method: .DELETE, use: closure)
    }

    /// GET path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func get<R: HBResponseFutureGenerator>(_ path: String = "", use closure: @escaping (HBRequest) -> R) -> Self {
        return add(path, method: .GET, use: closure)
    }

    /// PUT path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func put<R: HBResponseFutureGenerator>(_ path: String = "", use closure: @escaping (HBRequest) -> R) -> Self {
        return add(path, method: .PUT, use: closure)
    }

    /// DELETE path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func post<R: HBResponseFutureGenerator>(_ path: String = "", use closure: @escaping (HBRequest) -> R) -> Self {
        return add(path, method: .POST, use: closure)
    }

    /// POST path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func delete<R: HBResponseFutureGenerator>(_ path: String = "", use closure: @escaping (HBRequest) -> R) -> Self {
        return add(path, method: .DELETE, use: closure)
    }
}
