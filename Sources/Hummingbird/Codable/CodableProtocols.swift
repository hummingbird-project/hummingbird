import NIO

/// protocol for encoders generating ByteBuffers
public protocol ResponseEncoder {
    func encode<T: Encodable>(_ value: T, from request: Request) throws -> Response
}

/// protocol for decoder deserializing from ByteBuffers
public protocol RequestDecoder {
    func decode<T: Decodable>(_ type: T.Type, from request: Request) throws -> T
}

struct NullEncoder: ResponseEncoder {
    func encode<T: Encodable>(_ value: T, from request: Request) throws -> Response {
        return Response(
            status: .ok,
            headers: ["content-type": "text/plain; charset=utf-8"],
            body: .byteBuffer(request.allocator.buffer(string: "\(value)"))
        )
    }
}

struct NullDecoder: RequestDecoder {
    func decode<T: Decodable>(_ type: T.Type, from request: Request) throws -> T {
        preconditionFailure("Application.decoder has not been set")
    }
}
