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
    public func add<R: ResponseFutureEncodable>(_ path: String, method: HTTPMethod, closure: @escaping (Request) -> R) {
        let responder = CallbackResponder(callback: { request in closure(request).responseFuture(from: request) })
        add(path, method: method, responder: responder)
    }

    /// Add path for closure returning type conforming to Codable
    public func add<R: Encodable>(_ path: String, method: HTTPMethod, closure: @escaping (Request) -> R) {
        let responder = CallbackResponder(callback: { request in
            do {
                let value = closure(request)
                var buffer = request.allocator.buffer(capacity: 0)
                try request.application.encoder.encode(value, to: &buffer)
                let response = Response(status: .ok, headers: [:], body: .byteBuffer(buffer))
                return request.eventLoop.makeSucceededFuture(response)
            } catch {
                return request.eventLoop.makeFailedFuture(error)
            }
        })
        add(path, method: method, responder: responder)
    }

    /// Add path for closure returning `EventLoopFuture` of type conforming to Codable
    public func add<R: Encodable>(_ path: String, method: HTTPMethod, closure: @escaping (Request) -> EventLoopFuture<R>) {
        let responder = CallbackResponder(callback: { request in
            closure(request).flatMapThrowing { response in
                var buffer = request.allocator.buffer(capacity: 0)
                try request.application.encoder.encode(response, to: &buffer)
                return Response(status: .ok, headers: [:], body: .byteBuffer(buffer))
            }
        })
        add(path, method: method, responder: responder)
    }

    /// return new `RouterGroup` to add additional middleware to
    public func group() -> RouterGroup {
        return .init(router: self)
    }
}
