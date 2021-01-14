import Foundation
import HummingBird
import NIOFoundationCompat
@_exported import XMLCoding

extension XMLEncoder: ResponseEncoder {
    public func encode<T: Encodable>(_ value: T, from request: Request) throws -> Response {
        let xml = try self.encode(value)
        let xmlDocument = XML.Document(rootElement: xml)
        let xmlString = xmlDocument.xmlString
        var buffer = request.allocator.buffer(capacity: 0)
        buffer.writeString(xmlString)
        return Response(
            status: .ok,
            headers: ["content-type": "application/xml; charset=utf-8"],
            body: .byteBuffer(buffer)
        )
    }
}

extension XMLDecoder: RequestDecoder {
    public func decode<T: Decodable>(_ type: T.Type, from request: Request) throws -> T {
        guard var body = request.body,
            let data = body.readData(length: body.readableBytes) else {
            throw HTTPError(.badRequest)
        }
        let xml = try XML.Element(data: data)
        return try self.decode(T.self, from: xml)
    }
}
