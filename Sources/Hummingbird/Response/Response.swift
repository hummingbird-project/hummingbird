import NIO
import NIOHTTP1

/// HTTP Response
public class Response {
    /// response status
    public var status: HTTPResponseStatus
    /// response headers
    public var headers: HTTPHeaders
    /// response body
    public var body: ResponseBody
    /// Response extensions
    public var extensions: Extensions<Response>

    public init(status: HTTPResponseStatus, headers: HTTPHeaders, body: ResponseBody) {
        self.status = status
        self.headers = headers
        self.body = body
        self.extensions = Extensions()
    }
}
