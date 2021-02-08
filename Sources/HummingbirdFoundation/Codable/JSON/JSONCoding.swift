@_exported import class Foundation.JSONDecoder
@_exported import class Foundation.JSONEncoder
import Hummingbird
import NIOFoundationCompat

extension JSONEncoder: HBResponseEncoder {
    /// Extend JSONEncoder to support encoding `HBResponse`'s. Sets body and header values
    /// - Parameters:
    ///   - value: Value to encode
    ///   - request: Request used to generate response
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
    /// Extend JSONDecoder to decode from `HBRequest`.
    /// - Parameters:
    ///   - type: Type to decode
    ///   - request: Request to decode from
    public func decode<T: Decodable>(_ type: T.Type, from request: HBRequest) throws -> T {
        guard var buffer = request.body.buffer,
              let data = buffer.readData(length: buffer.readableBytes)
        else {
            throw HBHTTPError(.badRequest)
        }
        return try self.decode(T.self, from: data)
    }
}
