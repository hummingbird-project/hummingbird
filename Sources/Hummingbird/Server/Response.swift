import HummingbirdCore
import NIO
import NIOHTTP1

/// Holds all the required to generate a HTTP Response
public final class HBResponse: HBExtensible {
    /// response status
    public var status: HTTPResponseStatus
    /// response headers
    public var headers: HTTPHeaders
    /// response body
    public var body: HBResponseBody
    /// Response extensions
    public var extensions: HBExtensions<HBResponse>

    /// Create an `HBResponse`
    ///
    /// - Parameters:
    ///   - status: response status
    ///   - headers: response headers
    ///   - body: response body
    public init(status: HTTPResponseStatus, headers: HTTPHeaders = [:], body: HBResponseBody = .empty) {
        self.status = status
        self.headers = headers
        self.body = body
        self.extensions = HBExtensions()
    }
}
