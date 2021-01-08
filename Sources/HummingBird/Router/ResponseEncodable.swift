import NIO
import NIOHTTP1

public protocol ResponseEncodable {
    var response: Response { get }
}

extension Response : ResponseEncodable {
    public var response: Response { self }
}

extension ByteBuffer: ResponseEncodable {
    public var response: Response {
        Response(status: .ok, headers: [:], body: self)
    }
}

