import NIO
import NIOHTTP1

/// Default HTTP error. Provides an HTTP status and a message is so desired
public struct HBHTTPError: Error {
    /// status code for the error
    public let status: HTTPResponseStatus
    /// any addiitional headers required
    public let headers: HTTPHeaders
    /// error payload, assumed to be a string
    public let body: String?

    /// Initialize HTTPError
    /// - Parameters:
    ///   - status: HTTP status
    public init(_ status: HTTPResponseStatus) {
        self.status = status
        self.headers = [:]
        self.body = nil
    }

    /// Initialize HTTPError
    /// - Parameters:
    ///   - status: HTTP status
    ///   - message: Associated message
    public init(_ status: HTTPResponseStatus, message: String) {
        self.status = status
        self.headers = ["content-type": "text/plain; charset=utf-8"]
        self.body = message
    }

    /// Generate response from error
    /// - Parameter allocator: Byte buffer allocator used to allocate message body
    /// - Returns: Response
    public func response(version: HTTPVersion, allocator: ByteBufferAllocator) -> HBHTTPResponse {
        var headers: HTTPHeaders = self.headers

        let body: HBResponseBody
        if let message = self.body {
            let buffer = allocator.buffer(string: message)
            body = .byteBuffer(buffer)
            headers.replaceOrAdd(name: "content-length", value: buffer.readableBytes.description)
        } else {
            body = .empty
        }
        let responseHead = HTTPResponseHead(version: version, status: self.status, headers: headers)
        return .init(head: responseHead, body: body)
    }
}
