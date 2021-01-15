import NIO
import NIOHTTP1

/// Directs Requests to RequestResponders based on the request uri.
/// Conforms to RequestResponder so need to provide its own implementation of
/// `func apply(to request: Request) -> EventLoopFuture<Response>`
public protocol Router: RouterPaths, RequestResponder {
    /// Add router entry
    func add(_ path: String, method: HTTPMethod, responder: RequestResponder)
}

extension Router {
    /// Add path for closure returning type conforming to ResponseFutureEncodable
    public func add<R: ResponseGenerator>(_ path: String, method: HTTPMethod, closure: @escaping (Request) throws -> R) {
        let responder = CallbackResponder { request in
            request.body.consumeBody(on: request.eventLoop).flatMapThrowing { buffer in
                request.body = .byteBuffer(buffer)
                return try closure(request).response(from: request)
            }
        }
        add(path, method: method, responder: responder)
    }

    /// Add path for closure returning type conforming to ResponseFutureEncodable
    public func add<R: ResponseFutureGenerator>(_ path: String, method: HTTPMethod, closure: @escaping (Request) -> R) {
        let responder = CallbackResponder { request in
            request.body.consumeBody(on: request.eventLoop).flatMap { buffer in
                request.body = .byteBuffer(buffer)
                return closure(request).responseFuture(from: request)
            }
        }
        add(path, method: method, responder: responder)
    }

    /// return new `RouterGroup` to add additional middleware to
    public func group() -> RouterGroup {
        return .init(router: self)
    }
}
