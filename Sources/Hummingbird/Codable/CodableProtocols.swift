import NIO

/// protocol for encoders generating a Response
public protocol HBResponseEncoder {
    func encode<T: Encodable>(_ value: T, from request: HBRequest) throws -> HBResponse
}

/// protocol for decoder deserializing from a Request body
public protocol HBRequestDecoder {
    func decode<T: Decodable>(_ type: T.Type, from request: HBRequest) throws -> T
}

/// Default encoder. Outputs request with the swift string description of object
struct HBNullEncoder: HBResponseEncoder {
    func encode<T: Encodable>(_ value: T, from request: HBRequest) throws -> HBResponse {
        return HBResponse(
            status: .ok,
            headers: ["content-type": "text/plain; charset=utf-8"],
            body: .byteBuffer(request.allocator.buffer(string: "\(value)"))
        )
    }
}

/// Default decoder. there is no default decoder path so this generates an error
struct HBNullDecoder: HBRequestDecoder {
    func decode<T: Decodable>(_ type: T.Type, from request: HBRequest) throws -> T {
        preconditionFailure("Application.decoder has not been set")
    }
}
