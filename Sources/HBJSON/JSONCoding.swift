import Foundation
import HummingBird
import NIOFoundationCompat

extension JSONEncoder: EncoderProtocol {
    public func encode<T: Encodable>(_ value: T, to byteBuffer: inout ByteBuffer) throws {
        let data = try self.encode(value)
        byteBuffer.writeBytes(data)
    }
}

extension JSONDecoder: DecoderProtocol {
    public func decode<T: Decodable>(_ type: T.Type, from byteBuffer: inout ByteBuffer) throws -> T {
        guard let data = byteBuffer.readData(length: byteBuffer.readableBytes) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Empty Buffer"))
        }
        return try self.decode(T.self, from: data)
    }
}
