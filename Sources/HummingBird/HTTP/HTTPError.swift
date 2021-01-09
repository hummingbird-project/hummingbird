import NIOHTTP1

public struct HTTPError: Error {
    public let error: HTTPResponseStatus

    public init(_ error: HTTPResponseStatus) {
        self.error = error
    }
}
