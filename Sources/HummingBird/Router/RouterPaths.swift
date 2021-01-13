import NIO
import NIOHTTP1

public protocol RouterPaths {
    /// Add path for closure returning type conforming to ResponseFutureEncodable
    func add<R: ResponseFutureEncodable>(_ path: String, method: HTTPMethod, closure: @escaping (Request) -> R)
    /// Add path for closure returning type conforming to Codable
    func add<R: Encodable>(_ path: String, method: HTTPMethod, closure: @escaping (Request) -> R)
    /// Add path for closure returning `EventLoopFuture` of type conforming to Codable
    func add<R: Encodable>(_ path: String, method: HTTPMethod, closure: @escaping (Request) -> EventLoopFuture<R>)
}

extension RouterPaths {
    /// GET path for closure returning type conforming to ResponseFutureEncodable
    public func get<R: ResponseFutureEncodable>(_ path: String, closure: @escaping (Request) -> R) {
        add(path, method: .GET, closure: closure)
    }

    /// PUT path for closure returning type conforming to ResponseFutureEncodable
    public func put<R: ResponseFutureEncodable>(_ path: String, closure: @escaping (Request) -> R) {
        add(path, method: .PUT, closure: closure)
    }

    /// POST path for closure returning type conforming to ResponseFutureEncodable
    public func post<R: ResponseFutureEncodable>(_ path: String, closure: @escaping (Request) -> R) {
        add(path, method: .POST, closure: closure)
    }

    /// GET path for closure returning type conforming to Codable
    public func get<R: Encodable>(_ path: String, closure: @escaping (Request) -> R) {
        add(path, method: .GET, closure: closure)
    }

    /// PUT path for closure returning type conforming to Codable
    public func put<R: Encodable>(_ path: String, closure: @escaping (Request) -> R) {
        add(path, method: .PUT, closure: closure)
    }

    /// POST path for closure returning type conforming to Codable
    public func post<R: Encodable>(_ path: String, closure: @escaping (Request) -> R) {
        add(path, method: .POST, closure: closure)
    }

    /// GET path for closure returning `EventLoopFuture` of type conforming to Codable
    public func get<R: Encodable>(_ path: String, closure: @escaping (Request) -> EventLoopFuture<R>) {
        add(path, method: .GET, closure: closure)
    }

    /// PUT path for closure returning `EventLoopFuture` of type conforming to Codable
    public func put<R: Encodable>(_ path: String, closure: @escaping (Request) -> EventLoopFuture<R>) {
        add(path, method: .PUT, closure: closure)
    }

    /// POST path for closure returning `EventLoopFuture` of type conforming to Codable
    public func post<R: Encodable>(_ path: String, closure: @escaping (Request) -> EventLoopFuture<R>) {
        add(path, method: .POST, closure: closure)
    }
}
