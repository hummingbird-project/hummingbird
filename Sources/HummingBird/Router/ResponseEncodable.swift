
/// Protocol for encodable object that can generate a response
public protocol ResponseEncodable: Encodable, ResponseGenerator  {}

/// Protocol for codable object that can generate a response
public protocol ResponseCodable: ResponseEncodable, Decodable {}

/// Extend ResponseEncodable to conform to ResponseGenerator
extension ResponseEncodable {
    public func response(from request: Request) throws -> Response {
        var buffer = request.allocator.buffer(capacity: 0)
        try request.application.encoder.encode(self, to: &buffer)
        return Response(status: .ok, headers: [:], body: .byteBuffer(buffer))
    }
}

