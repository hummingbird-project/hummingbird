import NIO

/// protocol for encoders generating a Response
public protocol ResponseEncoder {
    func encode<T: Encodable>(_ value: T, from request: Request) throws -> Response
}

/// protocol for decoder deserializing from a Request body
public protocol RequestDecoder {
    func decode<T: Decodable>(_ type: T.Type, from request: Request) throws -> T
}

/// Default encoder. Outputs request with the swift string description of object
struct NullEncoder: ResponseEncoder {
    func encode<T: Encodable>(_ value: T, from request: Request) throws -> Response {
        return Response(
            status: .ok,
            headers: ["content-type": "text/plain; charset=utf-8"],
            body: .byteBuffer(request.allocator.buffer(string: "\(value)"))
        )
    }
}

/// Default decoder. there is no default decoder path so this generates an error
struct NullDecoder: RequestDecoder {
    func decode<T: Decodable>(_ type: T.Type, from request: Request) throws -> T {
        preconditionFailure("Application.decoder has not been set")
    }
}
