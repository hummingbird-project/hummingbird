import NIO
import NIOHTTP1

public protocol HBRouterMethods {
    /// Add path for closure returning type conforming to ResponseFutureEncodable
    func add<R: HBResponseGenerator>(_ path: String, method: HTTPMethod, closure: @escaping (HBRequest) throws -> R)
    /// Add path for closure returning type conforming to ResponseFutureEncodable
    func add<R: HBResponseFutureGenerator>(_ path: String, method: HTTPMethod, closure: @escaping (HBRequest) -> R)
}

extension HBRouterMethods {
    /// GET path for closure returning type conforming to ResponseFutureEncodable
    public func get<R: HBResponseGenerator>(_ path: String, closure: @escaping (HBRequest) throws -> R) {
        add(path, method: .GET, closure: closure)
    }

    /// PUT path for closure returning type conforming to ResponseFutureEncodable
    public func put<R: HBResponseGenerator>(_ path: String, closure: @escaping (HBRequest) throws -> R) {
        add(path, method: .PUT, closure: closure)
    }

    /// POST path for closure returning type conforming to ResponseFutureEncodable
    public func post<R: HBResponseGenerator>(_ path: String, closure: @escaping (HBRequest) throws -> R) {
        add(path, method: .POST, closure: closure)
    }

    /// DELETE path for closure returning type conforming to ResponseFutureEncodable
    public func delete<R: HBResponseGenerator>(_ path: String, closure: @escaping (HBRequest) throws -> R) {
        add(path, method: .DELETE, closure: closure)
    }

    /// GET path for closure returning type conforming to ResponseFutureEncodable
    public func get<R: HBResponseFutureGenerator>(_ path: String, closure: @escaping (HBRequest) -> R) {
        add(path, method: .GET, closure: closure)
    }

    /// PUT path for closure returning type conforming to ResponseFutureEncodable
    public func put<R: HBResponseFutureGenerator>(_ path: String, closure: @escaping (HBRequest) -> R) {
        add(path, method: .PUT, closure: closure)
    }

    /// DELETE path for closure returning type conforming to ResponseFutureEncodable
    public func post<R: HBResponseFutureGenerator>(_ path: String, closure: @escaping (HBRequest) -> R) {
        add(path, method: .POST, closure: closure)
    }

    /// POST path for closure returning type conforming to ResponseFutureEncodable
    public func delete<R: HBResponseFutureGenerator>(_ path: String, closure: @escaping (HBRequest) -> R) {
        add(path, method: .DELETE, closure: closure)
    }
}
