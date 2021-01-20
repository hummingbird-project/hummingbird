
/// Protocol for encodable object that can generate a response
public protocol ResponseEncodable: Encodable, ResponseGenerator  {}

/// Protocol for codable object that can generate a response
public protocol ResponseCodable: ResponseEncodable, Decodable {}

/// Extend ResponseEncodable to conform to ResponseGenerator
extension ResponseEncodable {
    public func response(from request: Request) throws -> Response {
        return try request.application.encoder.encode(self, from: request)
    }
}

