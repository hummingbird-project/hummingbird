import Foundation
import HummingBird
import NIOFoundationCompat

extension JSONEncoder: ResponseEncoder {
    public func encode<T: Encodable>(_ value: T, from request: Request) throws -> Response {
        var buffer = request.allocator.buffer(capacity: 0)
        let data = try self.encode(value)
        buffer.writeBytes(data)
        return Response(
            status: .ok,
            headers: ["content-type": "application/json; charset=utf-8"],
            body: .byteBuffer(buffer)
        )
    }
}

extension JSONDecoder: RequestDecoder {
    public func decode<T: Decodable>(_ type: T.Type, from request: Request) throws -> T {
        guard var body = request.body,
              let data = body.readData(length: body.readableBytes) else {
            throw HTTPError(.badRequest)
        }
        return try self.decode(T.self, from: data)
    }
}
