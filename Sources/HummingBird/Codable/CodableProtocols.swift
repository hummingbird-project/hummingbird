import NIO

/// protocol for encoders generating ByteBuffers
public protocol EncoderProtocol {
    func encode<T: Encodable>(_ value: T, to: inout ByteBuffer) throws
}

/// protocol for decoder deserializing from ByteBuffers
public protocol DecoderProtocol {
    func decode<T: Decodable>(_ type: T.Type, from byteBuffer: inout ByteBuffer) throws -> T
}

struct NullEncoder: EncoderProtocol {
    func encode<T: Encodable>(_ value: T, to: inout ByteBuffer) throws {
        to.writeString("\(value)")
    }
}

struct NullDecoder: DecoderProtocol {
    func decode<T: Decodable>(_ type: T.Type, from byteBuffer: inout ByteBuffer) throws -> T {
        preconditionFailure("Application.decoder has not been set")
    }
}
