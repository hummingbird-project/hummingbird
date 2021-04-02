import NIO

/// protocol for encoders generating a Response
public protocol HBResponseEncoder {
    /// Encode value returned by handler to request
    ///
    /// - Parameters:
    ///   - value: value to encode
    ///   - request: request that generated this value
    func encode<T: Encodable>(_ value: T, from request: HBRequest) throws -> HBResponse
}

/// protocol for decoder deserializing from a Request body
public protocol HBRequestDecoder {
    /// Decode type from request
    /// - Parameters:
    ///   - type: type to decode to
    ///   - request: request
    func decode<T: Decodable>(_ type: T.Type, from request: HBRequest) throws -> T
}

/// Default encoder. Outputs request with the swift string description of object
struct NullEncoder: HBResponseEncoder {
    func encode<T: Encodable>(_ value: T, from request: HBRequest) throws -> HBResponse {
        return HBResponse(
            status: .ok,
            headers: ["content-type": "text/plain; charset=utf-8"],
            body: .byteBuffer(request.allocator.buffer(string: "\(value)"))
        )
    }
}

/// Default decoder. there is no default decoder path so this generates an error
struct NullDecoder: HBRequestDecoder {
    func decode<T: Decodable>(_ type: T.Type, from request: HBRequest) throws -> T {
        preconditionFailure("HBApplication.decoder has not been set")
    }
}
