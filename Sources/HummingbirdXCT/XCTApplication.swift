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
        public let body: ByteBuffer
    }
    
    public enum XCTError: Error {
        case noHead
        case illegalBody
        case noEnd
    }
    
    var embeddedChannel: EmbeddedChannel {
        get { extensions.get(\.embeddedChannel) }
        set { extensions.set(\.embeddedChannel, value: newValue) }
    }
    
    var embeddedEventLoop: EmbeddedEventLoop {
        get { extensions.get(\.embeddedEventLoop) }
        set { extensions.set(\.embeddedEventLoop, value: newValue) }
    }
    
    var additionalChannels: [ChannelHandler] {
        get { extensions.get(\.additionalChannels) }
        set { extensions.set(\.additionalChannels, value: newValue) }
    }
    
    public enum XCTTestingEnum {
        case testing
    }
    
    public convenience init(_ testing: XCTTestingEnum, configuration: HBApplication.Configuration = .init()) {
        let embeddedEventLoop = EmbeddedEventLoop()
        self.init(configuration: configuration, eventLoopGroupProvider: .shared(embeddedEventLoop))
        self.embeddedEventLoop = embeddedEventLoop
        self.embeddedChannel = EmbeddedChannel()
        self.additionalChannels = []
    }
    
    public func XCTStart() {
        XCTAssertNoThrow(try self.embeddedChannel.pipeline.addHandlers(self.additionalChannels + [
            HBHTTPEncodeHandler(),
            HBHTTPDecodeHandler(configuration: self.configuration.httpServer),
            HBHTTPServerHandler(responder: HBApplication.HTTPResponder(application: self)),
        ]).wait())
    }

    public func XCTStop() {
        XCTAssertNoThrow(_ = try self.embeddedChannel.finish())
        XCTAssertNoThrow(try self.threadPool.syncShutdownGracefully())
        XCTAssertNoThrow(try self.eventLoopGroup.syncShutdownGracefully())
    }

    public func XCTAddChannelHandler(_ handler: ChannelHandler) {
        self.additionalChannels.append(handler)
    }
    
    public func XCTTestResponse(_ request: XCTRequest, _ testCallback: (XCTResponse) -> ()) throws {
        
        // write request
        do {
            let head = HTTPRequestHead(version: .init(major: 1, minor: 1), method: request.method, uri: request.uri, headers: request.headers)
            try writeInbound(.head(head))
            if let body = request.body {
                try writeInbound(.body(body))
            }
            try writeInbound(.end(nil))
        }
        // flush
        embeddedChannel.flush()
        
        // read response
        do {
            guard case .head(let head) = try readOutbound() else { throw XCTError.noHead }
            var next = try readOutbound()
            var buffer = embeddedChannel.allocator.buffer(capacity: 0)
            while case .body(let part) = next {
                guard case .byteBuffer(var b) = part else { throw XCTError.illegalBody }
                buffer.writeBuffer(&b)
                next = try readOutbound()
            }
            guard case .end = next else { throw XCTError.noEnd }
            
            testCallback(.init(status: head.status, headers: head.headers, body: buffer))
        }
    }
    
    func writeInbound(_ part: HTTPServerRequestPart) throws {
        try self.embeddedChannel.writeInbound(part)
    }
    
    func readOutbound() throws -> HTTPServerResponsePart? {
        return try self.embeddedChannel.readOutbound(as: HTTPServerResponsePart.self)
    }
}
