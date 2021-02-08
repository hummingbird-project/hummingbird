import NIO
import NIOHTTP1

/// Object that can generate a `Response`.
///
/// This is used by `Router` to convert handler return values into a `HBResponse`.
public protocol HBResponseGenerator {
    /// Generate response based on the request this object came from
    func response(from request: HBRequest) throws -> HBResponse
}

/// Extend Response to conform to ResponseGenerator
extension HBResponse: HBResponseGenerator {
    /// Return self as the response
    public func response(from request: HBRequest) -> HBResponse { self }
}

/// Extend String to conform to ResponseGenerator
extension String: HBResponseGenerator {
    /// Generate response holding string
    public func response(from request: HBRequest) -> HBResponse {
        let buffer = request.allocator.buffer(string: self)
        return HBResponse(status: .ok, headers: ["content-type": "text/plain; charset=utf-8"], body: .byteBuffer(buffer))
    }
}

/// Extend ByteBuffer to conform to ResponseGenerator
extension ByteBuffer: HBResponseGenerator {
    /// Generate response holding bytebuffer
    public func response(from request: HBRequest) -> HBResponse {
        HBResponse(status: .ok, headers: ["content-type": "application/octet-stream"], body: .byteBuffer(self))
    }
}

/// Extend HTTPResponseStatus to conform to ResponseGenerator
extension HTTPResponseStatus: HBResponseGenerator {
    /// Generate response with this response status code
    public func response(from request: HBRequest) -> HBResponse {
        HBResponse(status: self, headers: [:], body: .empty)
    }
}

/// Object that can generate a `EventLoopFuture<Response>`
///
/// This is used by `Router` to convert handler `EventLoopFuture` based return values into a
/// `EventLoopFuture<HBResponse>`.
public protocol HBResponseFutureGenerator {
    /// Generate `EventLoopFuture` that will be fulfilled with the response
    func responseFuture(from request: HBRequest) -> EventLoopFuture<HBResponse>
}

/// Extend EventLoopFuture of a ResponseEncodable to conform to ResponseFutureEncodable
extension EventLoopFuture: HBResponseFutureGenerator where Value: HBResponseGenerator {
    /// Generate `EventLoopFuture` that will be fulfilled with the response
    public func responseFuture(from request: HBRequest) -> EventLoopFuture<HBResponse> {
        return self.flatMapThrowing { try $0.response(from: request) }
    }
}
