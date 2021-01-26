import Hummingbird

/// response structure for XCT testing
public struct HBXCTResponse {
    public let status: HTTPResponseStatus
    public let headers: HTTPHeaders
    public let body: ByteBuffer?
}

/// Errors thrown when
public enum HBXCTError: Error {
    case noHead
    case illegalBody
    case noEnd
}

protocol HBXCT {
    func start(application: HBApplication)
    func stop()
    func execute(
        uri: String,
        method: HTTPMethod,
        headers: HTTPHeaders,
        body: ByteBuffer?
    ) -> EventLoopFuture<HBXCTResponse>
    var eventLoopGroup: EventLoopGroup { get }
}

