import HummingBird
import NIO
import NIOHTTP1
import NIOSSL

public final class HTTPClient {
    public enum Error: Swift.Error {
        case invalidURL
        case malformedResponse
    }
    public struct Request {
        public var uri: URI
        public var method: HTTPMethod
        public var headers: HTTPHeaders
        public var body: ByteBuffer?

        public init(uri: URI, method: HTTPMethod, headers: HTTPHeaders, body: ByteBuffer? = nil) {
            self.uri = uri
            self.method = method
            self.headers = headers
            self.body = body
        }

        public var port: Int {
            if let port = uri.port { return port }
            if uri.requiresTLS { return 443 }
            return 80
        }

        func clean() throws -> Request {
            guard let host = uri.host else { throw Error.invalidURL }
            var headers = self.headers
            headers.replaceOrAdd(name: "Host", value: String(host))
            headers.add(name: "User-Agent", value: "HummingBird/0.1")
            if let body = body {
                headers.replaceOrAdd(name: "Content-Length", value: body.readableBytes.description)
            }
            headers.replaceOrAdd(name: "Connection", value: "Close")

            return .init(uri: self.uri, method: self.method, headers: headers, body: self.body)
        }
    }

    public struct Response {
        public let headers: HTTPHeaders
        public let status: HTTPResponseStatus
        public let body: ByteBuffer?
    }

    public struct Configuration {
        public let tlsConfiguration: TLSConfiguration?

        public init(
            tlsConfiguration: TLSConfiguration? = nil
        ) {
            self.tlsConfiguration = tlsConfiguration
        }
    }

    public let eventLoopGroupProvider: NIOEventLoopGroupProvider
    public let eventLoopGroup: EventLoopGroup
    public let configuration: Configuration

    public init(eventLoopGroupProvider: NIOEventLoopGroupProvider, configuration: Configuration = Configuration()) {
        self.configuration = configuration
        self.eventLoopGroupProvider = eventLoopGroupProvider
        switch eventLoopGroupProvider {
        case .createNew:
            self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        case .shared(let elg):
            self.eventLoopGroup = elg
        }
    }

    public func syncShutdown() throws {
        switch self.eventLoopGroupProvider {
        case .createNew:
            try eventLoopGroup.syncShutdownGracefully()
        default:
            break
        }
    }

    public func execute(_ request: Request, on eventLoop: EventLoop? = nil) -> EventLoopFuture<Response> {
        let eventLoop = eventLoop ?? self.eventLoopGroup.next()
        do {
            let request = try request.clean()
            return execute(request, host: String(request.uri.host!), on: eventLoop)
        } catch {
            return eventLoop.makeFailedFuture(error)
        }
    }

    func execute(_ request: Request, host: String, on eventLoop: EventLoop) -> EventLoopFuture<Response> {
        let promise = eventLoop.makePromise(of: Response.self)
        do {
            try getBootstrap(request, host: host)
                .channelOption(ChannelOptions.socket(SocketOptionLevel(IPPROTO_TCP), TCP_NODELAY), value: 1)
                .channelInitializer { channel in
                    return channel.pipeline.addHTTPClientHandlers()
                        .flatMap {
                            let handlers: [ChannelHandler] = [
                                HTTPClientRequestSerializer(),
                                HTTPClientResponseHandler(promise: promise)
                            ]
                            return channel.pipeline.addHandlers(handlers)
                        }
                }
                .connect(host: host, port: request.port)
                .flatMap { channel in
                    return channel.writeAndFlush(request)
                }
                .cascadeFailure(to: promise)
        } catch {
            promise.fail(error)
        }

        return promise.futureResult
    }

    func getBootstrap(_ request: Request, host: String) throws -> NIOClientTCPBootstrap {
        let tlsConfiguration = configuration.tlsConfiguration ?? TLSConfiguration.forClient()
        let sslContext = try NIOSSLContext(configuration: tlsConfiguration)
        let tlsProvider = try NIOSSLClientTLSProvider<ClientBootstrap>(context: sslContext, serverHostname: host)
        let bootstrap = NIOClientTCPBootstrap(ClientBootstrap(group: eventLoopGroup), tls: tlsProvider)
        if request.uri.requiresTLS {
            bootstrap.enableTLS()
        }
        return bootstrap
    }

    /// Channel Handler for serializing request header and data
    private class HTTPClientRequestSerializer : ChannelOutboundHandler {
        typealias OutboundIn = Request
        typealias OutboundOut = HTTPClientRequestPart

        func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
            let request = unwrapOutboundIn(data)
            let head = HTTPRequestHead(
                version: .init(major: 1, minor: 1),
                method: request.method,
                uri: request.uri.string,
                headers: request.headers
            )
            context.write(wrapOutboundOut(.head(head)), promise: nil)

            if let body = request.body, body.readableBytes > 0 {
                context.write(self.wrapOutboundOut(.body(.byteBuffer(body))), promise: nil)
            }
            context.write(self.wrapOutboundOut(.end(nil)), promise: promise)
        }
    }

    /// Channel Handler for parsing response from server
    private class HTTPClientResponseHandler: ChannelInboundHandler {
        typealias InboundIn = HTTPClientResponsePart
        typealias OutboundOut = Response

        private enum ResponseState {
            /// Waiting to parse the next response.
            case idle
            /// received the head
            case head(HTTPResponseHead)
            /// Currently parsing the response's body.
            case body(HTTPResponseHead, ByteBuffer)
        }

        private var state: ResponseState = .idle
        private let promise : EventLoopPromise<Response>

        init(promise: EventLoopPromise<Response>) {
            self.promise = promise
        }

        func errorCaught(context: ChannelHandlerContext, error: Error) {
            context.fireErrorCaught(error)
        }

        func channelRead(context: ChannelHandlerContext, data: NIOAny) {
            let part = unwrapInboundIn(data)
            switch (part, state) {
            case (.head(let head), .idle):
                state = .head(head)
            case (.body(let body), .head(let head)):
                state = .body(head, body)
            case (.body(var part), .body(let head, var body)):
                body.writeBuffer(&part)
                state = .body(head, body)
            case (.end(let tailHeaders), .body(let head, let body)):
                assert(tailHeaders == nil, "Unexpected tail headers")
                let response = Response(
                    headers: head.headers,
                    status: head.status,
                    body: body
                )
                if context.channel.isActive {
                    context.fireChannelRead(wrapOutboundOut(response))
                }
                promise.succeed(response)
                state = .idle
            case (.end(let tailHeaders), .head(let head)):
                assert(tailHeaders == nil, "Unexpected tail headers")
                let response = Response(
                    headers: head.headers,
                    status: head.status,
                    body: nil
                )
                if context.channel.isActive {
                    context.fireChannelRead(wrapOutboundOut(response))
                }
                promise.succeed(response)
                state = .idle
            default:
                promise.fail(Error.malformedResponse)
            }
        }
    }
}
