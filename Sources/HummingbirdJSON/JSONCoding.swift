@_exported import class Foundation.JSONEncoder
@_exported import class Foundation.JSONDecoder
import Hummingbird
import NIOFoundationCompat

extension JSONEncoder: HBResponseEncoder {
    public func encode<T: Encodable>(_ value: T, from request: HBRequest) throws -> HBResponse {
        var buffer = request.allocator.buffer(capacity: 0)
        let data = try self.encode(value)
        buffer.writeBytes(data)
        return HBResponse(
            status: .ok,
            headers: ["content-type": "application/json; charset=utf-8"],
            body: .byteBuffer(buffer)
        )
    }
}

extension JSONDecoder: HBRequestDecoder {
    public func decode<T: Decodable>(_ type: T.Type, from request: HBRequest) throws -> T {
        guard var buffer = request.body.buffer,
              let data = buffer.readData(length: buffer.readableBytes) else {
            throw HBHTTPError(.badRequest)
        }
        return try self.decode(T.self, from: data)
    }
}
