import Hummingbird

extension URLEncodedFormEncoder: HBResponseEncoder {
    public func encode<T: Encodable>(_ value: T, from request: HBRequest) throws -> HBResponse {
        var buffer = request.allocator.buffer(capacity: 0)
        let string = try self.encode(value)
        buffer.writeString(string)
        return HBResponse(
            status: .ok,
            headers: ["content-type": "application/x-www-form-urlencoded"],
            body: .byteBuffer(buffer)
        )
    }
}

extension URLEncodedFormDecoder: HBRequestDecoder {
    public func decode<T: Decodable>(_ type: T.Type, from request: HBRequest) throws -> T {
        guard var buffer = request.body.buffer,
              let string = buffer.readString(length: buffer.readableBytes)
        else {
            throw HBHTTPError(.badRequest)
        }
        return try self.decode(T.self, from: string)
    }
}
