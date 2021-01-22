import NIO
import NIOHTTP1

/// Object that can generate a `Response`
public protocol HBResponseGenerator {
    func response(from request: HBRequest) throws -> HBResponse
}

/// Extend Response to conform to ResponseGenerator
extension HBResponse: HBResponseGenerator {
    public func response(from request: HBRequest) -> HBResponse { self }
}

/// Extend String to conform to ResponseGenerator
extension String: HBResponseGenerator {
    public func response(from request: HBRequest) -> HBResponse {
        let buffer = request.allocator.buffer(string: self)
        return HBResponse(status: .ok, headers: ["content-type": "text/plain; charset=utf-8"], body: .byteBuffer(buffer))
    }
}

/// Extend ByteBuffer to conform to ResponseGenerator
extension ByteBuffer: HBResponseGenerator {
    public func response(from request: HBRequest) -> HBResponse {
        HBResponse(status: .ok, headers: ["content-type": "application/octet-stream"], body: .byteBuffer(self))
    }
}

/// Extend HTTPResponseStatus to conform to ResponseGenerator
extension HTTPResponseStatus: HBResponseGenerator {
    public func response(from request: HBRequest) -> HBResponse {
        HBResponse(status: self, headers: [:], body: .empty)
    }
}

/// Object that can generate a `EventLoopFuture<Response>`
public protocol HBResponseFutureGenerator {
    func responseFuture(from request: HBRequest) -> EventLoopFuture<HBResponse>
}

/// Extend EventLoopFuture of a ResponseEncodable to conform to ResponseFutureEncodable
extension EventLoopFuture: HBResponseFutureGenerator where Value: HBResponseGenerator {
    public func responseFuture(from request: HBRequest) -> EventLoopFuture<HBResponse> {
        return self.flatMapThrowing { try $0.response(from: request) }
    }
}
