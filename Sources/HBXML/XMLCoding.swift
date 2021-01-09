import Foundation
import HummingBird
import NIOFoundationCompat
@_exported import XMLCoder

extension XMLEncoder: EncoderProtocol {
    public func encode<T: Encodable>(_ value: T, to byteBuffer: inout ByteBuffer) throws {
        let data = try self.encode(value, header: .init(version: 1, encoding: "UTF-8"))
        byteBuffer.writeBytes(data)
    }
}

extension XMLDecoder: DecoderProtocol {
    public func decode<T: Decodable>(_ type: T.Type, from byteBuffer: inout ByteBuffer) throws -> T {
        guard let data = byteBuffer.readData(length: byteBuffer.readableBytes) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Empty Buffer"))
        }
        return try self.decode(T.self, from: data)
    }
}
