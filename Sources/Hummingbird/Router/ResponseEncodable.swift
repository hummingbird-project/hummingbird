
/// Protocol for encodable object that can generate a response
public protocol HBResponseEncodable: Encodable, HBResponseGenerator  {}

/// Protocol for codable object that can generate a response
public protocol HBResponseCodable: HBResponseEncodable, Decodable {}

/// Extend ResponseEncodable to conform to ResponseGenerator
extension HBResponseEncodable {
    public func response(from request: HBRequest) throws -> HBResponse {
        return try request.application.encoder.encode(self, from: request)
    }
}

