import HTTPTypes

extension HTTPFields {
    init(contentType: String, contentLength: Int) {
        self.init()

        // Content-Type, Content-Length, Server, Date + 2 extra headers
        // This should cover our expected amount of headers
        self.reserveCapacity(6)

        self[.contentType] = contentType
        self[.contentLength] = String(describing: contentLength)
    }
}
