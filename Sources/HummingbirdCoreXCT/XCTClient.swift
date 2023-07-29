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

import NIOCore
import NIOHTTP1
import NIOPosix
import NIOSSL

/// Bare bones HTTP client that connects to one Server.
///
/// This is here for testing purposes
public struct HBXCTClient: Sendable {
    public let channelPromise: EventLoopPromise<Channel>
    let eventLoopGroup: EventLoopGroup
    let eventLoopGroupProvider: NIOEventLoopGroupProvider
    let host: String
    let port: Int
    let configuration: Configuration

    /// HBXCT configuration
    public struct Configuration: Sendable {
        public init(
            tlsConfiguration: TLSConfiguration? = nil,
            timeout: TimeAmount = .seconds(15),
            serverName: String? = nil
        ) {
            self.tlsConfiguration = tlsConfiguration
            self.timeout = timeout
            self.serverName = serverName
        }

        /// TLS confguration
        public let tlsConfiguration: TLSConfiguration?
        /// read timeout. If connection has no read events for indicated time throw timeout error
        public let timeout: TimeAmount
        /// server name
        public let serverName: String?
    }

    /// Initialize HBXCTClient
    /// - Parameters:
    ///   - host: host to connect
    ///   - port: port to connect to
    ///   - tlsConfiguration: TLS configuration if required
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
                    return channel.pipeline.addHTTPClientHandlers()
                        .flatMap {
                            let handlers: [ChannelHandler] = [
                                HTTPClientRequestSerializer(),
                                HTTPClientResponseHandler(),
                                HTTPTaskHandler(),
                            ]
                            return channel.pipeline.addHandlers(handlers)
                        }
                }
                .connectTimeout(.seconds(5))
                .connect(host: self.host, port: self.port)
                .cascade(to: self.channelPromise)
        } catch {
            self.channelPromise.fail(HBXCTClient.Error.tlsSetupFailed)
        }
    }

    /// shutdown client
    public func shutdown() async throws {
        do {
            try await self.close()
        } catch HBXCTClient.Error.connectionNotOpen {
        } catch ChannelError.alreadyClosed {}
        if case .createNew = self.eventLoopGroupProvider {
            try await self.eventLoopGroup.shutdownGracefully()
        }
    }

    /// GET request
    public func get(_ uri: String, headers: HTTPHeaders = [:]) async throws -> HBXCTClient.Response {
        let request = HBXCTClient.Request(uri, method: .GET, headers: headers)
        return try await self.execute(request)
    }

    /// HEAD request
    public func head(_ uri: String, headers: HTTPHeaders = [:]) async throws -> HBXCTClient.Response {
        let request = HBXCTClient.Request(uri, method: .HEAD, headers: headers)
        return try await self.execute(request)
    }

    /// PUT request
    public func put(_ uri: String, headers: HTTPHeaders = [:], body: ByteBuffer) async throws -> HBXCTClient.Response {
        let request = HBXCTClient.Request(uri, method: .PUT, headers: headers, body: body)
        return try await self.execute(request)
    }

    /// POST request
    public func post(_ uri: String, headers: HTTPHeaders = [:], body: ByteBuffer) async throws -> HBXCTClient.Response {
        let request = HBXCTClient.Request(uri, method: .POST, headers: headers, body: body)
        return try await self.execute(request)
    }

    /// DELETE request
    public func delete(_ uri: String, headers: HTTPHeaders = [:], body: ByteBuffer) async throws -> HBXCTClient.Response {
        let request = HBXCTClient.Request(uri, method: .DELETE, headers: headers, body: body)
        return try await self.execute(request)
    }

    /// Execute request to server. Return `EventLoopFuture` that will be fulfilled with HTTP response
    public func execute(_ request: HBXCTClient.Request) async throws -> HBXCTClient.Response {
        let channel = try await getChannel()
        let response = try await withThrowingTaskGroup(of: HBXCTClient.Response.self) { group in
            group.addTask {
                try await Task.sleep(nanoseconds: numericCast(self.configuration.timeout.nanoseconds))
                throw Error.readTimeout
            }
            group.addTask {
                let promise = self.eventLoopGroup.any().makePromise(of: HBXCTClient.Response.self)
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
        self.channelPromise.completeWith(.failure(HBXCTClient.Error.connectionNotOpen))
        let channel = try await getChannel()
        return try await channel.close()
    }

    public func getChannel() async throws -> Channel {
        try await self.channelPromise.futureResult.get()
    }

    private func cleanupRequest(_ request: HBXCTClient.Request) -> HBXCTClient.Request {
        var request = request
        if let contentLength = request.body.map(\.readableBytes) {
            request.headers.replaceOrAdd(name: "content-length", value: String(describing: contentLength))
        }
        return request
    }

    private func getBootstrap() throws -> NIOClientTCPBootstrap {
        if let tlsConfiguration = self.configuration.tlsConfiguration {
            let sslContext = try NIOSSLContext(configuration: tlsConfiguration)
            let tlsProvider = try NIOSSLClientTLSProvider<ClientBootstrap>(context: sslContext, serverHostname: self.configuration.serverName ?? self.host)
            let bootstrap = NIOClientTCPBootstrap(ClientBootstrap(group: self.eventLoopGroup), tls: tlsProvider)
            bootstrap.enableTLS()
            return bootstrap
        } else {
            return NIOClientTCPBootstrap(ClientBootstrap(group: self.eventLoopGroup), tls: NIOInsecureNoTLS())
        }
    }

    /// Channel Handler for serializing request header and data
    private class HTTPClientRequestSerializer: ChannelOutboundHandler {
        typealias OutboundIn = HBXCTClient.Request
        typealias OutboundOut = HTTPClientRequestPart

        func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
            let request = unwrapOutboundIn(data)
            let head = HTTPRequestHead(
                version: .init(major: 1, minor: 1),
                method: request.method,
                uri: request.uri,
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
        typealias InboundOut = HBXCTClient.Response

        private enum ResponseState {
            /// Waiting to parse the next response.
            case idle
            /// received the head
            case head(HTTPResponseHead)
            /// Currently parsing the response's body.
            case body(HTTPResponseHead, ByteBuffer)
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
            case (.end(let tailHeaders), .body(let head, let body)):
                assert(tailHeaders == nil, "Unexpected tail headers")
                let response = HBXCTClient.Response(
                    headers: head.headers,
                    status: head.status,
                    body: body
                )
                if context.channel.isActive {
                    context.fireChannelRead(wrapInboundOut(response))
                }
                self.state = .idle
            case (.end(let tailHeaders), .head(let head)):
                assert(tailHeaders == nil, "Unexpected tail headers")
                let response = HBXCTClient.Response(
                    headers: head.headers,
                    status: head.status,
                    body: nil
                )
                if context.channel.isActive {
                    context.fireChannelRead(wrapInboundOut(response))
                }
                self.state = .idle
            default:
                context.fireErrorCaught(HBXCTClient.Error.malformedResponse)
            }
        }
    }

    /// HTTP Task structure
    private struct HTTPTask {
        let request: HBXCTClient.Request
        let responsePromise: EventLoopPromise<HBXCTClient.Response>
    }

    /// HTTP Task handler. Kicks off HTTP Request and fulfills Response promise when response is returned
    private class HTTPTaskHandler: ChannelDuplexHandler {
        typealias InboundIn = HBXCTClient.Response
        typealias OutboundIn = HTTPTask
        typealias OutboundOut = HBXCTClient.Request

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
                    task.responsePromise.fail(HBXCTClient.Error.readTimeout)
                }

            default:
                context.fireUserInboundEventTriggered(event)
            }
        }
    }
}
