import HummingbirdCore

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

/// Extend Optional to conform to HBResponseGenerator
extension Optional: HBResponseGenerator where Wrapped: HBResponseEncodable {}

/// Extend Optional to conform to HBResponseEncodable
extension Optional: HBResponseEncodable where Wrapped: HBResponseEncodable {
    public func response(from request: HBRequest) throws -> HBResponse {
        switch self {
        case .some(let wrapped):
            return try request.application.encoder.encode(wrapped, from: request)
        case .none:
            throw HBHTTPError(.notFound)
        }
    }
}

/// Extend Array to conform to HBResponseGenerator
extension Array: HBResponseGenerator where Element: HBResponseEncodable {}

/// Extend Array to conform to HBResponseEncodable
extension Array: HBResponseEncodable where Element: HBResponseEncodable {
    public func response(from request: HBRequest) throws -> HBResponse {
        return try request.application.encoder.encode(self, from: request)
    }
}

/// Extend Dictionary to conform to HBResponseGenerator
extension Dictionary: HBResponseGenerator where Key: HBResponseEncodable, Value: HBResponseEncodable {}

/// Extend Array to conform to HBResponseEncodable
extension Dictionary: HBResponseEncodable where Key: HBResponseEncodable, Value: HBResponseEncodable {
    public func response(from request: HBRequest) throws -> HBResponse {
        return try request.application.encoder.encode(self, from: request)
    }
}

