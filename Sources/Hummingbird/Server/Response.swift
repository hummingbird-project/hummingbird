import HummingbirdCore
import NIO
import NIOHTTP1

/// HTTP Response
public final class HBResponse: HBExtensible {
    /// response status
    public var status: HTTPResponseStatus
    /// response headers
    public var headers: HTTPHeaders
    /// response body
    public var body: HBResponseBody
    /// Response extensions
    public var extensions: HBExtensions<HBResponse>

    public init(status: HTTPResponseStatus, headers: HTTPHeaders = [:], body: HBResponseBody = .empty) {
        self.status = status
        self.headers = headers
        self.body = body
        self.extensions = HBExtensions()
    }
}
