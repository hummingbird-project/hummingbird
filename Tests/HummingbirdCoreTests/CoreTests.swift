import AsyncHTTPClient
import HummingbirdCore
import Logging
import NIO
import NIOHTTP1
import XCTest

class HummingBirdCoreTests: XCTestCase {
    static var eventLoopGroup: EventLoopGroup!
    static var httpClient: HTTPClient!

    override class func setUp() {
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        self.httpClient = HTTPClient(eventLoopGroupProvider: .shared(self.eventLoopGroup))
    }

    override class func tearDown() {
        XCTAssertNoThrow(try self.httpClient.syncShutdown())
        XCTAssertNoThrow(try self.eventLoopGroup.syncShutdownGracefully())
    }

    func randomBuffer(size: Int) -> ByteBuffer {
        var data = [UInt8](repeating: 0, count: size)
        data = data.map { _ in UInt8.random(in: 0...255) }
        return ByteBufferAllocator().buffer(bytes: data)
    }

    func testConnect() {
        struct HelloResponder: HBHTTPResponder {
            func respond(to request: HBHTTPRequest, context: ChannelHandlerContext) -> EventLoopFuture<HBHTTPResponse> {
                let response = HBHTTPResponse(
                    head: .init(version: .init(major: 1, minor: 1), status: .ok),
                    body: .byteBuffer(context.channel.allocator.buffer(string: "Hello"))
                )
                return context.eventLoop.makeSucceededFuture(response)
            }
        }
        let server = HBHTTPServer(group: Self.eventLoopGroup, configuration: .init(address: .hostname(port: 8080)))
        XCTAssertNoThrow(try server.start(responder: HelloResponder()).wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let request = try! HTTPClient.Request(
            url: "http://localhost:\(server.configuration.address.port!)/"
        )
        let future = Self.httpClient.execute(request: request).flatMapThrowing { response in
            var body = try XCTUnwrap(response.body)
            XCTAssertEqual(body.readString(length: body.readableBytes), "Hello")
        }
        XCTAssertNoThrow(try future.wait())
    }

    func testConsumeBody() {
        struct Responder: HBHTTPResponder {
            func respond(to request: HBHTTPRequest, context: ChannelHandlerContext) -> EventLoopFuture<HBHTTPResponse> {
                return request.body.consumeBody(on: context.eventLoop).flatMapThrowing { buffer in
                    guard let buffer = buffer else {
                        throw HBHTTPError(.badRequest)
                    }
                    return HBHTTPResponse(
                        head: .init(version: .init(major: 1, minor: 1), status: .ok),
                        body: .byteBuffer(buffer)
                    )
                }
            }
        }
        let server = HBHTTPServer(group: Self.eventLoopGroup, configuration: .init(address: .hostname(port: 8080), maxStreamingBufferSize: 256 * 1024))
        XCTAssertNoThrow(try server.start(responder: Responder()).wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let buffer = self.randomBuffer(size: 1_140_000)
        let request = try! HTTPClient.Request(
            url: "http://localhost:\(server.configuration.address.port!)/",
            body: .byteBuffer(buffer)
        )
        let future = Self.httpClient.execute(request: request)
            .flatMapThrowing { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(body, buffer)
            }
        XCTAssertNoThrow(try future.wait())
    }

    func testConsumeAllBody() {
        struct Responder: HBHTTPResponder {
            func respond(to request: HBHTTPRequest, context: ChannelHandlerContext) -> EventLoopFuture<HBHTTPResponse> {
                var size = 0
                return request.body.streamBody(on: context.eventLoop).consumeAll(on: context.eventLoop) { buffer in
                    size += buffer.readableBytes
                    return context.eventLoop.makeSucceededFuture(())
                }
                .flatMapThrowing { _ in
                    return HBHTTPResponse(
                        head: .init(version: .init(major: 1, minor: 1), status: .ok),
                        body: .byteBuffer(context.channel.allocator.buffer(integer: size))
                    )
                }
            }
        }
        let server = HBHTTPServer(group: Self.eventLoopGroup, configuration: .init(address: .hostname(port: 8080), maxStreamingBufferSize: 256 * 1024))
        XCTAssertNoThrow(try server.start(responder: Responder()).wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let buffer = self.randomBuffer(size: 450_000)
        let request = try! HTTPClient.Request(
            url: "http://localhost:\(server.configuration.address.port!)/",
            body: .byteBuffer(buffer)
        )
        let future = Self.httpClient.execute(request: request)
            .flatMapThrowing { response in
                var body = try XCTUnwrap(response.body)
                XCTAssertEqual(body.readInteger(), buffer.readableBytes)
            }
        XCTAssertNoThrow(try future.wait())
    }

    func testStreamBody() {
        struct Responder: HBHTTPResponder {
            func respond(to request: HBHTTPRequest, context: ChannelHandlerContext) -> EventLoopFuture<HBHTTPResponse> {
                let body: HBResponseBody = .streamCallback { _ in
                    return request.body.stream.consume(on: context.eventLoop).map { output in
                        switch output {
                        case .byteBuffer(let buffer):
                            return .byteBuffer(buffer)
                        case .end:
                            return .end
                        }
                    }
                }
                let response = HBHTTPResponse(
                    head: .init(version: .init(major: 1, minor: 1), status: .ok),
                    body: body
                )
                return context.eventLoop.makeSucceededFuture(response)
            }
        }
        let server = HBHTTPServer(group: Self.eventLoopGroup, configuration: .init(address: .hostname(port: 8080), maxStreamingBufferSize: 256 * 1024))
        XCTAssertNoThrow(try server.start(responder: Responder()).wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let buffer = self.randomBuffer(size: 1_140_000)
        let request = try! HTTPClient.Request(
            url: "http://localhost:\(server.configuration.address.port!)/",
            body: .byteBuffer(buffer)
        )
        let future = Self.httpClient.execute(request: request)
            .flatMapThrowing { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(body, buffer)
            }
        XCTAssertNoThrow(try future.wait())
    }

    func testStreamBodySlowProcess() {
        struct Responder: HBHTTPResponder {
            func respond(to request: HBHTTPRequest, context: ChannelHandlerContext) -> EventLoopFuture<HBHTTPResponse> {
                let body: HBResponseBody = .streamCallback { _ in
                    return request.body.stream.consume(on: context.eventLoop).flatMap { output in
                        switch output {
                        case .byteBuffer(let buffer):
                            // delay processing of buffer
                            return context.eventLoop.scheduleTask(in: .milliseconds(Int64.random(in: 0..<200))) { .byteBuffer(buffer) }.futureResult
                        case .end:
                            return context.eventLoop.makeSucceededFuture(.end)
                        }
                    }
                }
                let response = HBHTTPResponse(
                    head: .init(version: .init(major: 1, minor: 1), status: .ok),
                    body: body
                )
                return context.eventLoop.makeSucceededFuture(response)
            }
        }
        let server = HBHTTPServer(group: Self.eventLoopGroup, configuration: .init(address: .hostname(port: 8080), maxStreamingBufferSize: 256 * 1024))
        XCTAssertNoThrow(try server.start(responder: Responder()).wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let buffer = self.randomBuffer(size: 1_140_000)
        let request = try! HTTPClient.Request(
            url: "http://localhost:\(server.configuration.address.port!)/",
            body: .byteBuffer(buffer)
        )
        let future = Self.httpClient.execute(request: request)
            .flatMapThrowing { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(body, buffer)
            }
        XCTAssertNoThrow(try future.wait())
    }

    func testStreamBodySlowStream() {
        /// channel handler that delays the sending of data
        class SlowInputChannelHandler: ChannelOutboundHandler {
            public typealias OutboundIn = Never
            public typealias OutboundOut = HTTPServerResponsePart

            func read(context: ChannelHandlerContext) {
                context.eventLoop.scheduleTask(in: .milliseconds(Int64.random(in: 25..<200))) {
                    context.read()
                }
            }
        }
        struct Responder: HBHTTPResponder {
            func respond(to request: HBHTTPRequest, context: ChannelHandlerContext) -> EventLoopFuture<HBHTTPResponse> {
                return request.body.consumeBody(on: context.eventLoop).flatMapThrowing { buffer in
                    guard let buffer = buffer else {
                        throw HBHTTPError(.badRequest)
                    }
                    return HBHTTPResponse(
                        head: .init(version: .init(major: 1, minor: 1), status: .ok),
                        body: .byteBuffer(buffer)
                    )
                }
            }
        }
        let server = HBHTTPServer(group: Self.eventLoopGroup, configuration: .init(address: .hostname(port: 8080)))
        server.addChannelHandler(SlowInputChannelHandler())
        XCTAssertNoThrow(try server.start(responder: Responder()).wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let buffer = self.randomBuffer(size: 1_140_000)
        let request = try! HTTPClient.Request(
            url: "http://localhost:\(server.configuration.address.port!)/",
            body: .byteBuffer(buffer)
        )
        let future = Self.httpClient.execute(request: request)
            .flatMapThrowing { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(body, buffer)
            }
        XCTAssertNoThrow(try future.wait())
    }

    func testChannelHandlerErrorPropagation() {
        class CreateErrorHandler: ChannelInboundHandler {
            typealias InboundIn = HTTPServerRequestPart

            var seen: Bool = false
            func channelRead(context: ChannelHandlerContext, data: NIOAny) {
                if case .body = self.unwrapInboundIn(data) {
                    context.fireErrorCaught(HBHTTPError(.insufficientStorage))
                }
                context.fireChannelRead(data)
            }
        }
        struct Responder: HBHTTPResponder {
            func respond(to request: HBHTTPRequest, context: ChannelHandlerContext) -> EventLoopFuture<HBHTTPResponse> {
                let response = HBHTTPResponse(
                    head: .init(version: .init(major: 1, minor: 1), status: .accepted),
                    body: .empty
                )
                return context.eventLoop.makeSucceededFuture(response)
            }
        }
        let server = HBHTTPServer(group: Self.eventLoopGroup, configuration: .init(address: .hostname(port: 8080)))
        server.addChannelHandler(CreateErrorHandler())
        XCTAssertNoThrow(try server.start(responder: Responder()).wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let buffer = self.randomBuffer(size: 32)
        let request = try! HTTPClient.Request(
            url: "http://localhost:\(server.configuration.address.port!)/",
            body: .byteBuffer(buffer)
        )
        let future = Self.httpClient.execute(request: request)
            .flatMapThrowing { response in
                XCTAssertEqual(response.status, .insufficientStorage)
            }
        XCTAssertNoThrow(try future.wait())
    }

    func testMaxUploadSize() {
        struct Responder: HBHTTPResponder {
            func respond(to request: HBHTTPRequest, context: ChannelHandlerContext) -> EventLoopFuture<HBHTTPResponse> {
                return request.body.consumeBody(on: context.eventLoop).flatMapThrowing { buffer in
                    guard let buffer = buffer else {
                        throw HBHTTPError(.badRequest)
                    }
                    return HBHTTPResponse(
                        head: .init(version: .init(major: 1, minor: 1), status: .ok),
                        body: .byteBuffer(buffer)
                    )
                }
            }
        }
        let server = HBHTTPServer(group: Self.eventLoopGroup, configuration: .init(address: .hostname(port: 8080), maxUploadSize: 64 * 1024))
        XCTAssertNoThrow(try server.start(responder: Responder()).wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let buffer = self.randomBuffer(size: 320_000)
        let request = try! HTTPClient.Request(
            url: "http://localhost:\(server.configuration.address.port!)/",
            body: .byteBuffer(buffer)
        )
        let future = Self.httpClient.execute(request: request)
            .flatMapThrowing { response in
                XCTAssertEqual(response.status, .payloadTooLarge)
            }
        XCTAssertNoThrow(try future.wait())
    }
}
