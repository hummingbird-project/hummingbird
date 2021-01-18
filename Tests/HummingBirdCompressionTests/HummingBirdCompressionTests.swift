import AsyncHTTPClient
import HummingBird
import HummingBirdCompression
import XCTest

class HummingBirdCompressionTests: XCTestCase {
    struct Error: Swift.Error {}

    public class VerifyBufferCompressedHandler: ChannelOutboundHandler {
        public typealias OutboundIn = HTTPServerResponsePart
        public typealias OutboundOut = HTTPServerResponsePart

        let size: Int

        init(size: Int) {
            self.size = size
        }
        public func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
            if case .body(let bytebuffer) = unwrapOutboundIn(data) {
                XCTAssertNotEqual(size, bytebuffer.readableBytes)
            }
            context.write(data, promise: promise)
        }
    }
    func testCompressResponse() {
        let lorem = """
        Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim
        veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate
        velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit
        anim id est laborum.

        Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo
        inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo. Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit
        aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt. Neque porro quisquam est, qui dolorem ipsum quia
        dolor sit amet, consectetur, adipisci velit, sed quia non numquam eius modi tempora incidunt ut labore et dolore magnam aliquam quaerat
        voluptatem. Ut enim ad minima veniam, quis nostrum exercitationem ullam corporis suscipit laboriosam, nisi ut aliquid ex ea commodi
        consequatur? Quis autem vel eum iure reprehenderit qui in ea voluptate velit esse quam nihil molestiae consequatur, vel illum qui dolorem eum
        fugiat quo voluptas nulla pariatur?
        """
        let app = Application()
        app.httpServer
            .addChildChannelHandler(VerifyBufferCompressedHandler(size: lorem.utf8.count), position: .afterHTTP)
            .addResponseCompression()
        app.router.get("/lorem") { request in
            return lorem
        }
        app.start()
        defer { app.stop(); app.wait() }

        let client = HTTPClient(eventLoopGroupProvider: .shared(app.eventLoopGroup), configuration: .init(decompression: .enabled(limit: .none)))
        defer { XCTAssertNoThrow(try client.syncShutdown()) }

        let response =  client.get(url: "http://localhost:\(app.configuration.port)/lorem").flatMapThrowing { response in
            guard var body = response.body,
                  let string = body.readString(length: body.readableBytes) else
            {
                throw HummingBirdCompressionTests.Error()
            }
            XCTAssertEqual(lorem, string)
        }
        XCTAssertNoThrow(try response.wait())
    }

}
