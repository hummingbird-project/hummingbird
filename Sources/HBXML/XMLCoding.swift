import Foundation
import HummingBird
import NIOFoundationCompat
@_exported import XMLCoding

extension XMLEncoder: EncoderProtocol {
    public func encode<T: Encodable>(_ value: T, to byteBuffer: inout ByteBuffer) throws {
        let xml = try self.encode(value)
        let xmlDocument = XML.Document(rootElement: xml)
        let xmlString = xmlDocument.xmlString
        byteBuffer.writeString(xmlString)
    }
}

extension XMLDecoder: DecoderProtocol {
    public func decode<T: Decodable>(_ type: T.Type, from byteBuffer: inout ByteBuffer) throws -> T {
        guard let data = byteBuffer.readData(length: byteBuffer.readableBytes) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Empty Buffer"))
        }
        let xml = try XML.Element(data: data)
        return try self.decode(T.self, from: xml)
    }
}

