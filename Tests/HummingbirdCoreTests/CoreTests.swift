import AsyncHTTPClient
import HummingbirdCore
import Logging
import NIO
import NIOHTTP1
import XCTest

class HummingBirdCoreTests: XCTestCase {
    struct HelloResponder: HBHTTPResponder {
        func respond(to request: HBHTTPRequest, context: ChannelHandlerContext) -> EventLoopFuture<HBHTTPResponse> {
            let response = HBHTTPResponse(
                head: .init(version: .init(major: 1, minor: 1), status: .ok),
                body: .byteBuffer(context.channel.allocator.buffer(string: "Hello"))
            )
            return context.eventLoop.makeSucceededFuture(response)
        }
    }
    
    func testConnect() throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        defer { XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully()) }
        let server = HBHTTPServer(group: eventLoopGroup, configuration: .init(address: .hostname(port: 8000)))
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
