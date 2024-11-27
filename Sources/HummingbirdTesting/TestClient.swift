//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import HTTPTypes
import NIOCore
import NIOHTTPTypes
import NIOHTTPTypesHTTP1
import NIOPosix
import NIOSSL

/// Bare bones single connection HTTP client.
///
/// This HTTP client is used for internal testing of Hummingbird and is also
/// the client used by `.live` testing framework.
public struct TestClient: Sendable {
    public let channelPromise: EventLoopPromise<Channel>
    let eventLoopGroup: EventLoopGroup
    let eventLoopGroupProvider: NIOEventLoopGroupProvider
    let host: String
    let port: Int
    let configuration: Configuration

    /// TestClient configuration
    public struct Configuration: Sendable {
        public init(
            tlsConfiguration: TLSConfiguration? = nil,
            timeout: Duration = .seconds(15),
            serverName: String? = nil
        ) {
            self.tlsConfiguration = tlsConfiguration
            self.timeout = timeout
            self.serverName = serverName
        }

        /// TLS confguration
        public let tlsConfiguration: TLSConfiguration?
        /// read timeout. If connection has no read events for indicated time throw timeout error
        public let timeout: Duration
        /// server name
        public let serverName: String?
    }

    /// Initialize TestClient
    /// - Parameters:
    ///   - host: host to connect
    ///   - port: port to connect to
    ///   - configuration: Client configuration
    ///   - eventLoopGroupProvider: EventLoopGroup to use
    public init(
        host: String,
        port: Int,
        configuration: Configuration = .init(),
        eventLoopGroupProvider: NIOEventLoopGroupProvider
    ) {
        self.eventLoopGroupProvider = eventLoopGroupProvider
        switch eventLoopGroupProvider {
        case .createNew:
            self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        case .shared(let elg):
            self.eventLoopGroup = elg
        }
        self.channelPromise = self.eventLoopGroup.next().makePromise()
        self.host = host
        self.port = port
        self.configuration = configuration
    }

    /// connect to HTTP server
    public func connect() {
        do {
            try self.getBootstrap()
                .channelOption(ChannelOptions.socket(SocketOptionLevel(IPPROTO_TCP), TCP_NODELAY), value: 1)
                .channelInitializer { channel in
                    channel.pipeline.addHTTPClientHandlers()
                        .flatMapThrowing {
                            let handlers: [ChannelHandler] = [
                                HTTP1ToHTTPClientCodec(),
                                HTTPClientRequestSerializer(),
                                HTTPClientResponseHandler(),
                                HTTPTaskHandler(),
                            ]
                            return try channel.pipeline.syncOperations.addHandlers(handlers)
                        }
                }
                .connectTimeout(.seconds(5))
                .connect(host: self.host, port: self.port)
                .cascade(to: self.channelPromise)
        } catch {
            self.channelPromise.fail(TestClient.Error.tlsSetupFailed)
        }
    }

    /// shutdown client
    public func shutdown() async throws {
        do {
            try await self.close()
        } catch TestClient.Error.connectionNotOpen {
        } catch ChannelError.alreadyClosed {}
        if case .createNew = self.eventLoopGroupProvider {
            try await self.eventLoopGroup.shutdownGracefully()
        }
    }

    /// GET request
    public func get(_ uri: String, headers: HTTPFields = [:]) async throws -> TestClient.Response {
        let request = TestClient.Request(uri, method: .get, headers: headers)
        return try await self.execute(request)
    }

    /// HEAD request
    public func head(_ uri: String, headers: HTTPFields = [:]) async throws -> TestClient.Response {
        let request = TestClient.Request(uri, method: .head, headers: headers)
        return try await self.execute(request)
    }

    /// PUT request
    public func put(_ uri: String, headers: HTTPFields = [:], body: ByteBuffer) async throws -> TestClient.Response {
        let request = TestClient.Request(uri, method: .put, headers: headers, body: body)
        return try await self.execute(request)
    }

    /// POST request
    public func post(_ uri: String, headers: HTTPFields = [:], body: ByteBuffer) async throws -> TestClient.Response {
        let request = TestClient.Request(uri, method: .post, headers: headers, body: body)
        return try await self.execute(request)
    }

    /// DELETE request
    public func delete(_ uri: String, headers: HTTPFields = [:], body: ByteBuffer) async throws -> TestClient.Response {
        let request = TestClient.Request(uri, method: .delete, headers: headers, body: body)
        return try await self.execute(request)
    }

    /// Execute request to server. Return `EventLoopFuture` that will be fulfilled with HTTP response
    public func execute(_ request: TestClient.Request) async throws -> TestClient.Response {
        let channel = try await getChannel()
        let response = try await withThrowingTaskGroup(of: TestClient.Response.self) { group in
            group.addTask {
                try await Task.sleep(for: self.configuration.timeout)
                throw Error.readTimeout
            }
            group.addTask {
                let promise = self.eventLoopGroup.any().makePromise(of: TestClient.Response.self)
                let task = HTTPTask(request: self.cleanupRequest(request), responsePromise: promise)
                channel.writeAndFlush(task, promise: nil)
                return try await promise.futureResult.get()
            }
            let response = try await group.next()
            group.cancelAll()
            return response!
        }
        return response
    }

    public func close() async throws {
        self.channelPromise.completeWith(.failure(TestClient.Error.connectionNotOpen))
        let channel = try await getChannel()
        return try await channel.close()
    }

    public func getChannel() async throws -> Channel {
        try await self.channelPromise.futureResult.get()
    }

    private func cleanupRequest(_ request: TestClient.Request) -> TestClient.Request {
        var request = request
        if let contentLength = request.body.map(\.readableBytes) {
            request.headers[.contentLength] = String(describing: contentLength)
        }
        return request
    }

    private func getBootstrap() throws -> NIOClientTCPBootstrap {
        if let tlsConfiguration = self.configuration.tlsConfiguration {
            let sslContext = try NIOSSLContext(configuration: tlsConfiguration)
            let tlsProvider = try NIOSSLClientTLSProvider<ClientBootstrap>(
                context: sslContext,
                serverHostname: self.configuration.serverName ?? self.host
            )
            let bootstrap = NIOClientTCPBootstrap(ClientBootstrap(group: self.eventLoopGroup), tls: tlsProvider)
            bootstrap.enableTLS()
            return bootstrap
        } else {
            return NIOClientTCPBootstrap(ClientBootstrap(group: self.eventLoopGroup), tls: NIOInsecureNoTLS())
        }
    }

    /// Channel Handler for serializing request header and data
    private class HTTPClientRequestSerializer: ChannelOutboundHandler {
        typealias OutboundIn = TestClient.Request
        typealias OutboundOut = HTTPRequestPart

        func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
            let request = unwrapOutboundIn(data)
            context.write(wrapOutboundOut(.head(request.head)), promise: nil)

            if let body = request.body, body.readableBytes > 0 {
                context.write(self.wrapOutboundOut(.body(body)), promise: nil)
            }
            context.write(self.wrapOutboundOut(.end(nil)), promise: promise)
        }
    }

    /// Channel Handler for parsing response from server
    private class HTTPClientResponseHandler: ChannelInboundHandler {
        typealias InboundIn = HTTPResponsePart
        typealias InboundOut = TestClient.Response

        private enum ResponseState {
            /// Waiting to parse the next response.
            case idle
            /// received the head
            case head(HTTPResponse)
            /// Currently parsing the response's body.
            case body(HTTPResponse, ByteBuffer)
        }

        private var state: ResponseState = .idle

        func channelRead(context: ChannelHandlerContext, data: NIOAny) {
            let part = unwrapInboundIn(data)
            switch (part, self.state) {
            case (.head(let head), .idle):
                state = .head(head)
            case (.body(let body), .head(let head)):
                self.state = .body(head, body)
            case (.body(var part), .body(let head, var body)):
                body.writeBuffer(&part)
                self.state = .body(head, body)
            case (.end(let trailerHeaders), .body(let head, let body)):
                let response = TestClient.Response(
                    head: head,
                    body: body,
                    trailerHeaders: trailerHeaders
                )
                if context.channel.isActive {
                    context.fireChannelRead(wrapInboundOut(response))
                }
                self.state = .idle
            case (.end(let trailerHeaders), .head(let head)):
                let response = TestClient.Response(
                    head: head,
                    body: nil,
                    trailerHeaders: trailerHeaders
                )
                if context.channel.isActive {
                    context.fireChannelRead(wrapInboundOut(response))
                }
                self.state = .idle
            default:
                context.fireErrorCaught(TestClient.Error.malformedResponse)
            }
        }
    }

    /// HTTP Task structure
    private struct HTTPTask {
        let request: TestClient.Request
        let responsePromise: EventLoopPromise<TestClient.Response>
    }

    /// HTTP Task handler. Kicks off HTTP Request and fulfills Response promise when response is returned
    private class HTTPTaskHandler: ChannelDuplexHandler {
        typealias InboundIn = TestClient.Response
        typealias OutboundIn = HTTPTask
        typealias OutboundOut = TestClient.Request

        var queue: CircularBuffer<HTTPTask>

        init() {
            self.queue = .init(initialCapacity: 4)
        }

        func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
            let task = unwrapOutboundIn(data)
            self.queue.append(task)
            context.write(wrapOutboundOut(task.request), promise: promise)
        }

        func channelInactive(context: ChannelHandlerContext) {
            // if error caught, pass to all tasks in progress and close channel
            while let task = self.queue.popFirst() {
                task.responsePromise.fail(Error.connectionClosing)
            }
        }

        func channelRead(context: ChannelHandlerContext, data: NIOAny) {
            let response = unwrapInboundIn(data)
            if let task = self.queue.popFirst() {
                task.responsePromise.succeed(response)
            }
        }

        func errorCaught(context: ChannelHandlerContext, error: Error) {
            // if error caught, pass to all tasks in progress and close channel
            while let task = self.queue.popFirst() {
                task.responsePromise.fail(error)
            }
            context.close(promise: nil)
        }

        func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
            switch event {
            case let evt as IdleStateHandler.IdleStateEvent where evt == .read:
                while let task = self.queue.popFirst() {
                    task.responsePromise.fail(TestClient.Error.readTimeout)
                }

            default:
                context.fireUserInboundEventTriggered(event)
            }
        }
    }
}
