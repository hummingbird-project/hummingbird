import NIO
import NIOHTTP1

/// Object that can generate a `Response`
public protocol ResponseGenerator {
    func response(from request: Request) throws -> Response
}

/// Extend Response to conform to ResponseGenerator
extension Response: ResponseGenerator {
    public func response(from request: Request) -> Response { self }
}

/// Extend String to conform to ResponseGenerator
extension String: ResponseGenerator {
    public func response(from request: Request) -> Response {
        let buffer = request.allocator.buffer(string: self)
        return Response(status: .ok, headers: ["content-type": "text/plain; charset=utf-8"], body: .byteBuffer(buffer))
    }
}

/// Extend ByteBuffer to conform to ResponseGenerator
extension ByteBuffer: ResponseGenerator {
    public func response(from request: Request) -> Response {
        Response(status: .ok, headers: ["content-type": "application/octet-stream"], body: .byteBuffer(self))
    }
}

/// Extend HTTPResponseStatus to conform to ResponseGenerator
extension HTTPResponseStatus: ResponseGenerator {
    public func response(from request: Request) -> Response {
        Response(status: self, headers: [:], body: .empty)
    }
}

/// Object that can generate a `EventLoopFuture<Response>`
public protocol ResponseFutureGenerator {
    func responseFuture(from request: Request) -> EventLoopFuture<Response>
}

/// Extend EventLoopFuture of a ResponseEncodable to conform to ResponseFutureEncodable
extension EventLoopFuture: ResponseFutureGenerator where Value: ResponseGenerator {
    public func responseFuture(from request: Request) -> EventLoopFuture<Response> {
        return self.flatMapThrowing { try $0.response(from: request) }
    }
}
