import AsyncHTTPClient
import HummingbirdCore
import Logging
import NIO
import NIOHTTP1
import XCTest

class HummingBirdCoreTests: XCTestCase {
    struct HelloResponder: HTTPResponder {
        func respond(to request: HTTPRequest, context: ChannelHandlerContext) -> EventLoopFuture<HTTPResponse> {
            let responseHead = HTTPResponseHead(version: .init(major: 1, minor: 1), status: .ok)
            let responseBody = context.channel.allocator.buffer(string: "Hello")
            let response = HTTPResponse(head: responseHead, body: .byteBuffer(responseBody))
            return context.eventLoop.makeSucceededFuture(response)
        }
        
        var logger: Logger? = Logger(label: "Core")
    }
    
    func testConnect() throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        defer { XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully()) }
        let server = HTTPServer(group: eventLoopGroup, configuration: .init(address: .hostname(port: 8000)))
        try server.start(responder: HelloResponder()).wait()
        defer { XCTAssertNoThrow(try server.stop().wait()) }
        
        let client = HTTPClient(eventLoopGroupProvider: .shared(eventLoopGroup))
        defer { XCTAssertNoThrow(try client.syncShutdown()) }

        let future = client.get(url: "http://localhost:\(server.configuration.address.port!)/").flatMapThrowing { response in
            var body = try XCTUnwrap(response.body)
            XCTAssertEqual(body.readString(length: body.readableBytes), "Hello")
        }
        XCTAssertNoThrow(try future.wait())
    }
}
