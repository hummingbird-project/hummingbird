import NIO
import NIOHTTP1

/// Object that can be encoded into a `Response`
public protocol ResponseEncodable {
    var response: Response { get }
}

extension Response : ResponseEncodable {
    public var response: Response { self }
}

extension ByteBuffer: ResponseEncodable {
    public var response: Response {
        Response(status: .ok, headers: [:], body: .byteBuffer(self))
    }
}

extension HTTPResponseStatus: ResponseEncodable {
    public var response: Response {
        Response(status: self, headers: [:], body: .empty)
    }
}

/// Object that can be encoded into a `EventLoopFuture<Response>`
public protocol ResponseFutureEncodable {
    func responseFuture(from request: Request) -> EventLoopFuture<Response>
}

extension Response : ResponseFutureEncodable {
    public func responseFuture(from request: Request) -> EventLoopFuture<Response> {
        request.eventLoop.makeSucceededFuture(self)
    }
}

extension ByteBuffer: ResponseFutureEncodable {
    public func responseFuture(from request: Request) -> EventLoopFuture<Response> {
        let response = Response(status: .ok, headers: [:], body: .byteBuffer(self))
        return request.eventLoop.makeSucceededFuture(response)
    }
}

extension HTTPResponseStatus: ResponseFutureEncodable {
    public func responseFuture(from request: Request) -> EventLoopFuture<Response> {
        let response = Response(status: self, headers: [:], body: .empty)
        return request.eventLoop.makeSucceededFuture(response)
    }
}

extension EventLoopFuture: ResponseFutureEncodable where Value: ResponseEncodable {
    public func responseFuture(from request: Request) -> EventLoopFuture<Response> {
        return self.map { $0.response }
    }
}
