import Hummingbird
import NIO
import NIOHTTP1
import XCTest

/// Test application by running on an EmbeddedChannel
struct HBXCTEmbedded: HBXCT {
    init() {
        let embeddedEventLoop = EmbeddedEventLoop()
        self.embeddedEventLoop = embeddedEventLoop
        self.embeddedChannel = EmbeddedChannel()
    }

    /// Start tests
    func start(application: HBApplication) {
        XCTAssertNoThrow(try self.embeddedChannel.pipeline.addHandlers(application.server.additionalChannelHandlers(at: .afterHTTP) + [
            HBHTTPEncodeHandler(),
            HBHTTPDecodeHandler(configuration: application.configuration.httpServer),
            HBHTTPServerHandler(responder: HBApplication.HTTPResponder(application: application)),
        ]).wait())
    }

    /// Stop tests
    func stop() {
        XCTAssertNoThrow(_ = try self.embeddedChannel.finish())
        XCTAssertNoThrow(_ = try self.embeddedEventLoop.syncShutdownGracefully())
    }

    /// Send request and call test callback on the response returned
    func execute(
        uri: String,
        method: HTTPMethod,
        headers: HTTPHeaders = [:],
        body: ByteBuffer? = nil
    ) -> EventLoopFuture<HBXCTResponse> {
        do {
            // write request
            let requestHead = HTTPRequestHead(version: .init(major: 1, minor: 1), method: method, uri: uri, headers: headers)
            try writeInbound(.head(requestHead))
            if let body = body {
                try self.writeInbound(.body(body))
            }
            try self.writeInbound(.end(nil))

            // flush
            self.embeddedChannel.flush()

            // read response
            guard case .head(let head) = try readOutbound() else { throw HBXCTError.noHead }
            var next = try readOutbound()
            var buffer = self.embeddedChannel.allocator.buffer(capacity: 0)
            while case .body(let part) = next {
                guard case .byteBuffer(var b) = part else { throw HBXCTError.illegalBody }
                buffer.writeBuffer(&b)
                next = try readOutbound()
            }
            guard case .end = next else { throw HBXCTError.noEnd }

            return self.embeddedEventLoop.makeSucceededFuture(.init(status: head.status, headers: head.headers, body: buffer))
        } catch {
            return self.embeddedEventLoop.makeFailedFuture(error)
        }
    }

    var eventLoopGroup: EventLoopGroup { return self.embeddedEventLoop }

    func writeInbound(_ part: HTTPServerRequestPart) throws {
        try self.embeddedChannel.writeInbound(part)
    }

    func readOutbound() throws -> HTTPServerResponsePart? {
        return try self.embeddedChannel.readOutbound(as: HTTPServerResponsePart.self)
    }

    let embeddedChannel: EmbeddedChannel
    let embeddedEventLoop: EmbeddedEventLoop
}
