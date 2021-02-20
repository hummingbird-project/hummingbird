import HummingbirdCore

/// Protocol for encodable object that can generate a response. The router will encode
/// the response using the encoder stored in `HBApplication.encoder`.
public protocol HBResponseEncodable: Encodable, HBResponseGenerator {}

/// Protocol for codable object that can generate a response
public protocol HBResponseCodable: HBResponseEncodable, Decodable {}

/// Extend ResponseEncodable to conform to ResponseGenerator
extension HBResponseEncodable {
    public func response(from request: HBRequest) throws -> HBResponse {
        return try request.application.encoder.encode(self, from: request)
    }
}

/// Extend Array to conform to HBResponseGenerator
extension Array: HBResponseGenerator where Element: Encodable {}

/// Extend Array to conform to HBResponseEncodable
extension Array: HBResponseEncodable where Element: Encodable {
    public func response(from request: HBRequest) throws -> HBResponse {
        return try request.application.encoder.encode(self, from: request)
    }
}

/// Extend Dictionary to conform to HBResponseGenerator
extension Dictionary: HBResponseGenerator where Key: Encodable, Value: Encodable {}

/// Extend Array to conform to HBResponseEncodable
extension Dictionary: HBResponseEncodable where Key: Encodable, Value: Encodable {
    public func response(from request: HBRequest) throws -> HBResponse {
        return try request.application.encoder.encode(self, from: request)
    }
}
