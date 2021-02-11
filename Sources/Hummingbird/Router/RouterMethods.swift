import NIO
import NIOHTTP1

public protocol HBRouterMethods {
    /// Add path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult func on<R: HBResponseGenerator>(_ path: String, method: HTTPMethod, use: @escaping (HBRequest) throws -> R) -> Self
    /// Add path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult func on<R: HBResponseFutureGenerator>(_ path: String, method: HTTPMethod, use: @escaping (HBRequest) -> R) -> Self
}

extension HBRouterMethods {
    /// GET path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func get<R: HBResponseGenerator>(_ path: String = "", use closure: @escaping (HBRequest) throws -> R) -> Self {
        return on(path, method: .GET, use: closure)
    }

    /// PUT path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func put<R: HBResponseGenerator>(_ path: String = "", use closure: @escaping (HBRequest) throws -> R) -> Self {
        return on(path, method: .PUT, use: closure)
    }

    /// POST path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func post<R: HBResponseGenerator>(_ path: String = "", use closure: @escaping (HBRequest) throws -> R) -> Self {
        return on(path, method: .POST, use: closure)
    }

    /// HEAD path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func head<R: HBResponseGenerator>(_ path: String = "", use closure: @escaping (HBRequest) throws -> R) -> Self {
        return on(path, method: .HEAD, use: closure)
    }

    /// DELETE path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func delete<R: HBResponseGenerator>(_ path: String = "", use closure: @escaping (HBRequest) throws -> R) -> Self {
        return on(path, method: .DELETE, use: closure)
    }

    /// PATCH path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func patch<R: HBResponseGenerator>(_ path: String = "", use closure: @escaping (HBRequest) throws -> R) -> Self {
        return on(path, method: .PATCH, use: closure)
    }

    /// GET path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func get<R: HBResponseFutureGenerator>(_ path: String = "", use closure: @escaping (HBRequest) -> R) -> Self {
        return on(path, method: .GET, use: closure)
    }

    /// PUT path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func put<R: HBResponseFutureGenerator>(_ path: String = "", use closure: @escaping (HBRequest) -> R) -> Self {
        return on(path, method: .PUT, use: closure)
    }

    /// POST path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func delete<R: HBResponseFutureGenerator>(_ path: String = "", use closure: @escaping (HBRequest) -> R) -> Self {
        return on(path, method: .DELETE, use: closure)
    }

    /// HEAD path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func head<R: HBResponseFutureGenerator>(_ path: String = "", use closure: @escaping (HBRequest) -> R) -> Self {
        return on(path, method: .HEAD, use: closure)
    }

    /// DELETE path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func post<R: HBResponseFutureGenerator>(_ path: String = "", use closure: @escaping (HBRequest) -> R) -> Self {
        return on(path, method: .POST, use: closure)
    }

    /// PATCH path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func patch<R: HBResponseFutureGenerator>(_ path: String = "", use closure: @escaping (HBRequest) -> R) -> Self {
        return on(path, method: .PATCH, use: closure)
    }
}
