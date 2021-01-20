import NIOHTTP1

public struct HTTPError: Error {
    public let status: HTTPResponseStatus
    public let message: String?

    public init(_ status: HTTPResponseStatus, message: String? = nil) {
        self.status = status
        self.message = message
    }

    public func response(allocator: ByteBufferAllocator) -> Response {
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
        return Response(status: self.status, headers: headers, body: body)
    }
}
