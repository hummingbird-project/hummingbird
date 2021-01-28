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
    @discardableResult public func on<R: HBResponseGenerator>(
        _ path: String,
        method: HTTPMethod,
        use closure: @escaping (HBRequest) throws -> R
    ) -> Self {
        let responder = CallbackResponder { request in
            request.body.consumeBody(on: request.eventLoop).flatMapThrowing { buffer in
                request.body = .byteBuffer(buffer)
                return try closure(request).response(from: request)
            }
        }
        add(path, method: method, responder: responder)
        return self
    }

    /// Add path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func on<R: HBResponseFutureGenerator>(
        _ path: String,
        method: HTTPMethod,
        use closure: @escaping (HBRequest) -> R
    ) -> Self {
        let responder = CallbackResponder { request in
            request.body.consumeBody(on: request.eventLoop).flatMap { buffer in
                request.body = .byteBuffer(buffer)
                return closure(request).responseFuture(from: request).hop(to: request.eventLoop)
            }
        }
        add(path, method: method, responder: responder)
        return self
    }

    /// Add path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func onStreaming<R: HBResponseFutureGenerator>(
        _ path: String,
        method: HTTPMethod,
        use closure: @escaping (HBRequest) -> R
    ) -> Self {
        let responder = CallbackResponder { request in
            let streamer = request.body.streamBody(on: request.eventLoop)
            request.body = .stream(streamer)
            return closure(request).responseFuture(from: request).hop(to: request.eventLoop)
        }
        add(path, method: method, responder: responder)
        return self
    }

    /// return new `RouterEndpoint`
    public func endpoint(_ path: String) -> HBRouterEndpoint {
        return .init(path: path, router: self)
    }
}
