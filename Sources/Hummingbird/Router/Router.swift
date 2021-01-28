import HummingbirdCore
import NIO
import NIOHTTP1

/// Directs Requests to RequestResponders based on the request uri.
/// Conforms to RequestResponder so need to provide its own implementation of
/// `func apply(to request: Request) -> EventLoopFuture<Response>`
public protocol HBRouter: HBRouterMethods, HBResponder {
    /// Add router entry
    func add(_ path: String, method: HTTPMethod, responder: HBResponder)
}

extension HBRouter {
    /// Add path for closure returning type conforming to ResponseFutureEncodable
    public func add<R: HBResponseGenerator>(_ path: String, method: HTTPMethod, use closure: @escaping (HBRequest) throws -> R) {
        let responder = CallbackResponder { request in
            request.body.consumeBody(on: request.eventLoop).flatMapThrowing { buffer in
                request.body = .byteBuffer(buffer)
                return try closure(request).response(from: request)
            }
        }
        add(path, method: method, responder: responder)
    }

    /// Add path for closure returning type conforming to ResponseFutureEncodable
    public func add<R: HBResponseFutureGenerator>(_ path: String, method: HTTPMethod, use closure: @escaping (HBRequest) -> R) {
        let responder = CallbackResponder { request in
            request.body.consumeBody(on: request.eventLoop).flatMap { buffer in
                request.body = .byteBuffer(buffer)
                return closure(request).responseFuture(from: request).hop(to: request.eventLoop)
            }
        }
        add(path, method: method, responder: responder)
    }

    /// Add path for closure returning type conforming to ResponseFutureEncodable
    public func addStreamingRoute<R: HBResponseFutureGenerator>(_ path: String, method: HTTPMethod, use closure: @escaping (HBRequest) -> R) {
        let responder = CallbackResponder { request in
            let streamer = request.body.streamBody(on: request.eventLoop)
            request.body = .stream(streamer)
            return closure(request).responseFuture(from: request).hop(to: request.eventLoop)
        }
        add(path, method: method, responder: responder)
    }

    /// return new `RouterGroup` to add additional middleware to
    public func group() -> HBRouterGroup {
        return .init(router: self)
    }
}
