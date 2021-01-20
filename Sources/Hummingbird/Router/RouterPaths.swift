import NIO
import NIOHTTP1

public protocol RouterPaths {
    /// Add path for closure returning type conforming to ResponseFutureEncodable
    func add<R: ResponseGenerator>(_ path: String, method: HTTPMethod, closure: @escaping (Request) throws -> R)
    /// Add path for closure returning type conforming to ResponseFutureEncodable
    func add<R: ResponseFutureGenerator>(_ path: String, method: HTTPMethod, closure: @escaping (Request) -> R)
}

extension RouterPaths {
    /// GET path for closure returning type conforming to ResponseFutureEncodable
    public func get<R: ResponseGenerator>(_ path: String, closure: @escaping (Request) throws -> R) {
        add(path, method: .GET, closure: closure)
    }

    /// PUT path for closure returning type conforming to ResponseFutureEncodable
    public func put<R: ResponseGenerator>(_ path: String, closure: @escaping (Request) throws -> R) {
        add(path, method: .PUT, closure: closure)
    }

    /// POST path for closure returning type conforming to ResponseFutureEncodable
    public func post<R: ResponseGenerator>(_ path: String, closure: @escaping (Request) throws -> R) {
        add(path, method: .POST, closure: closure)
    }

    /// GET path for closure returning type conforming to ResponseFutureEncodable
    public func get<R: ResponseFutureGenerator>(_ path: String, closure: @escaping (Request) -> R) {
        add(path, method: .GET, closure: closure)
    }

    /// PUT path for closure returning type conforming to ResponseFutureEncodable
    public func put<R: ResponseFutureGenerator>(_ path: String, closure: @escaping (Request) -> R) {
        add(path, method: .PUT, closure: closure)
    }

    /// POST path for closure returning type conforming to ResponseFutureEncodable
    public func post<R: ResponseFutureGenerator>(_ path: String, closure: @escaping (Request) -> R) {
        add(path, method: .POST, closure: closure)
    }
}
