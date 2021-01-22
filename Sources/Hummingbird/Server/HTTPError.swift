import NIOHTTP1

/// Default HTTP error. Provides an HTTP status and a message is so desired
public struct HTTPError: Error {
    public let status: HTTPResponseStatus
    public let message: String?

    /// Initialize HTTPError
    /// - Parameters:
    ///   - status: HTTP status
    ///   - message: Associated message
    public init(_ status: HTTPResponseStatus, message: String? = nil) {
        self.status = status
        self.message = message
    }

    /// Generate response from error
    /// - Parameter allocator: Byte buffer allocator used to allocate message body
    /// - Returns: Response
    public func response(allocator: ByteBufferAllocator) -> HTTPResponse {
        let body: ResponseBody
        var headers: HTTPHeaders = [:]

        if let message = self.message {
            let buffer = allocator.buffer(string: message)
            body = .byteBuffer(buffer)
            headers.replaceOrAdd(name: "content-type", value: "text/plain; charset=utf-8")
            headers.replaceOrAdd(name: "content-length", value: buffer.readableBytes.description)
        } else {
            body = .empty
        }
        let responseHead = HTTPResponseHead(version: .init(major: 1, minor: 1), status: self.status, headers: headers)
        return .init(head: responseHead, body: body)
    }
}
