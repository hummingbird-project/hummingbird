import Hummingbird
import NIO
import NIOHTTP1
import XCTest

extension HBApplication {
    public struct XCTRequest {
        public let uri: String
        public let method: HTTPMethod
        public let headers: HTTPHeaders
        public let body: ByteBuffer?

        public init(uri: String, method: HTTPMethod, headers: HTTPHeaders = [:], body: ByteBuffer? = nil) {
            self.uri = uri
            self.method = method
            self.headers = headers
            self.body = body
        }
    }
    
    public struct XCTResponse {
        public let status: HTTPResponseStatus
        public let headers: HTTPHeaders
        public let body: ByteBuffer?
    }
    
    var embeddedChannel: EmbeddedChannel {
        get { extensions.get(\.embeddedChannel) }
        set { extensions.set(\.embeddedChannel, value: newValue) }
    }
    
    var embeddedEventLoop: EmbeddedEventLoop {
        get { extensions.get(\.embeddedEventLoop) }
        set { extensions.set(\.embeddedEventLoop, value: newValue) }
    }
    
    public enum TestingEnum {
        case testing
    }
    
    public convenience init(_ testing: TestingEnum) {
        let embeddedEventLoop = EmbeddedEventLoop()
        self.init(eventLoopGroupProvider: .shared(embeddedEventLoop))
        self.embeddedEventLoop = embeddedEventLoop
        self.embeddedChannel = EmbeddedChannel()
    }
    
    public func xctStart() throws {
        try self.embeddedChannel.pipeline.addHandlers([
            HBHTTPEncodeHandler(),
            HBHTTPDecodeHandler(configuration: .init()),
            HBHTTPServerHandler(responder: HBApplication.HTTPResponder(application: self)),
        ]).wait()
    }

    public func xctRequest(_ request: XCTRequest) throws -> XCTResponse? {
        let head = HTTPRequestHead(version: .init(major: 1, minor: 1), method: request.method, uri: request.uri, headers: request.headers)
        
        XCTAssertNoThrow(try writeInbound(.head(head)))
        if let body = request.body {
            XCTAssertNoThrow(try writeInbound(.body(body)))
        }
        XCTAssertNoThrow(try writeInbound(.end(nil)))
        try embeddedChannel.flush()
        do {
            guard case .head(let head) = try readOutbound() else { return nil }
            var next = try readOutbound()
            var buffer = embeddedChannel.allocator.buffer(capacity: 0)
            while case .body(let part) = next {
                guard case .byteBuffer(var b) = part else { return nil }
                buffer.writeBuffer(&b)
                next = try readOutbound()
            }
            guard case .end = next else { return nil }
            return XCTResponse(status: head.status, headers: head.headers, body: buffer)
        } catch {
            XCTFail()
            return nil
        }
    }
    
    func writeInbound(_ part: HTTPServerRequestPart) throws {
        try self.embeddedChannel.writeInbound(part)
    }
    
    func readOutbound() throws -> HTTPServerResponsePart? {
        return try self.embeddedChannel.readInbound(as: HTTPServerResponsePart.self)
    }
    
    public func xctStop() throws {
        _ = try self.embeddedChannel.finish()
        try self.threadPool.syncShutdownGracefully()
        try self.eventLoopGroup.syncShutdownGracefully()
    }
}
