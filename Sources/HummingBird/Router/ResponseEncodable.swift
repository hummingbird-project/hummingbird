import NIO
import NIOHTTP1

/// Object that can be encoded into a `EventLoopFuture<Response>`
public protocol ResponseFutureEncodable {
    func responseFuture(from request: Request) -> EventLoopFuture<Response>
}

/// Object that can be encoded into a `Response`
public protocol ResponseEncodable: ResponseFutureEncodable {
    func response(from request: Request) -> Response
}

extension ResponseEncodable {
    public func responseFuture(from request: Request) -> EventLoopFuture<Response> {
        request.eventLoop.makeSucceededFuture(response(from: request))
    }
}

extension Response : ResponseEncodable {
    public func response(from request: Request) -> Response { self }
}

extension ByteBuffer: ResponseEncodable {
    public func response(from request: Request) -> Response {
        Response(status: .ok, headers: [:], body: .byteBuffer(self))
    }
}

extension HTTPResponseStatus: ResponseEncodable {
    public func response(from request: Request) -> Response {
        Response(status: self, headers: [:], body: .empty)
    }
}

extension EventLoopFuture: ResponseFutureEncodable where Value: ResponseEncodable {
    public func responseFuture(from request: Request) -> EventLoopFuture<Response> {
        return self.map { $0.response(from: request) }
    }
}
