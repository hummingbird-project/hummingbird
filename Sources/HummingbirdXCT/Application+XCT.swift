import Hummingbird
import NIO
import NIOHTTP1
import XCTest

extension HBApplication {
    /// response structure 
    public struct XCTResponse {
        public let status: HTTPResponseStatus
        public let headers: HTTPHeaders
        public let body: ByteBuffer
    }
    
    /// Errors thrown when
    public enum XCTError: Error {
        case noHead
        case illegalBody
        case noEnd
    }
    
    public enum XCTTestingEnum {
        case testing
    }
    
    /// Initialization for when testing
    /// - Parameters:
    ///   - testing: indicate we are testing
    ///   - configuration: configuration
    public convenience init(_ testing: XCTTestingEnum, configuration: HBApplication.Configuration = .init()) {
        let embeddedEventLoop = EmbeddedEventLoop()
        self.init(configuration: configuration, eventLoopGroupProvider: .shared(embeddedEventLoop))
        self.xctEmbeddedEventLoop = embeddedEventLoop
        self.xctEmbeddedChannel = EmbeddedChannel()
    }
    
    /// Start tests
    public func XCTStart() {
        XCTAssertNoThrow(try self.xctEmbeddedChannel.pipeline.addHandlers(self.server.additionalChannelHandlers(at: .afterHTTP) + [
            HBHTTPEncodeHandler(),
            HBHTTPDecodeHandler(configuration: self.configuration.httpServer),
            HBHTTPServerHandler(responder: HBApplication.HTTPResponder(application: self)),
        ]).wait())
    }
    
    /// Stop tests
    public func XCTStop() {
        XCTAssertNoThrow(_ = try self.xctEmbeddedChannel.finish())
        XCTAssertNoThrow(try self.threadPool.syncShutdownGracefully())
        XCTAssertNoThrow(try self.eventLoopGroup.syncShutdownGracefully())
    }
    
    /// Send request and call test callback on the response returned
    public func XCTTestResponse(
        uri: String,
        method: HTTPMethod,
        headers: HTTPHeaders = [:],
        body: ByteBuffer? = nil,
        _ testCallback: (XCTResponse) -> ()
    ) throws {
        // write request
        do {
            let head = HTTPRequestHead(version: .init(major: 1, minor: 1), method: method, uri: uri, headers: headers)
            try writeInbound(.head(head))
            if let body = body {
                try writeInbound(.body(body))
            }
            try writeInbound(.end(nil))
        }
        // flush
        xctEmbeddedChannel.flush()
        
        // read response
        do {
            guard case .head(let head) = try readOutbound() else { throw XCTError.noHead }
            var next = try readOutbound()
            var buffer = xctEmbeddedChannel.allocator.buffer(capacity: 0)
            while case .body(let part) = next {
                guard case .byteBuffer(var b) = part else { throw XCTError.illegalBody }
                buffer.writeBuffer(&b)
                next = try readOutbound()
            }
            guard case .end = next else { throw XCTError.noEnd }
            
            testCallback(.init(status: head.status, headers: head.headers, body: buffer))
        }
    }
    
    var xctEmbeddedChannel: EmbeddedChannel {
        get { extensions.get(\.xctEmbeddedChannel) }
        set { extensions.set(\.xctEmbeddedChannel, value: newValue) }
    }

    var xctEmbeddedEventLoop: EmbeddedEventLoop {
        get { extensions.get(\.xctEmbeddedEventLoop) }
        set { extensions.set(\.xctEmbeddedEventLoop, value: newValue) }
    }

    func writeInbound(_ part: HTTPServerRequestPart) throws {
        try self.xctEmbeddedChannel.writeInbound(part)
    }
    
    func readOutbound() throws -> HTTPServerResponsePart? {
        return try self.xctEmbeddedChannel.readOutbound(as: HTTPServerResponsePart.self)
    }
}
