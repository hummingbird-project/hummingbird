import NIOHTTP1

public struct HTTPError: Error {
    public let status: HTTPResponseStatus

    public init(_ status: HTTPResponseStatus) {
        self.status = status
    }
}
