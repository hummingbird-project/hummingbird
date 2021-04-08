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

import NIO
import NIOExtras
import NIOHTTP1

/// HTTP server class
public class HBHTTPServer {
    /// EventLoopGroup used by server
    public let eventLoopGroup: EventLoopGroup
    /// Server configuration
    public let configuration: Configuration
    /// object initializing HTTP child handlers. This defaults to creating an HTTP1 channel
    public var httpChannelInitializer: HBChannelInitializer
    /// Server channel
    public var channel: Channel?

    var quiesce: ServerQuiescingHelper?

    /// HTTP server errors
    public enum Error: Swift.Error {
        /// waiting on the server while it is not running will throw this
        case serverNotRunning
    }

    /// Initialize HTTP server
    /// - Parameters:
    ///   - group: EventLoopGroup server uses
    ///   - configuration: Configuration for server
    public init(group: EventLoopGroup, configuration: Configuration) {
        self.eventLoopGroup = group
        self.configuration = configuration
        self.quiesce = nil
        self.childChannelHandlers = .init()
        // defaults to HTTP1
        self.httpChannelInitializer = HTTP1ChannelInitializer()
    }

    /// Add TLS handler. Need to provide a closure so new instance of these handlers are
    /// created for each child channel
    /// - Parameters:
    ///   - handler: autoclosure generating handler
    ///   - position: position to place channel handler
    @discardableResult public func addTLSChannelHandler(_ handler: @autoclosure @escaping () -> RemovableChannelHandler) -> Self {
        self.tlsChannelHandler = handler
        return self
    }

    /// Append to list of `ChannelHandler`s to be added to server child channels. Need to provide a closure so new instance of these handlers are
    /// created for each child channel
    /// - Parameters:
    ///   - handler: autoclosure generating handler
    ///   - position: position to place channel handler
    @discardableResult public func addChannelHandler(_ handler: @autoclosure @escaping () -> RemovableChannelHandler) -> Self {
        self.childChannelHandlers.addHandler(handler())
        return self
    }

    /// Start server
    /// - Parameter responder: Object that provides responses to requests sent to the server
    /// - Returns: EventLoopFuture that is fulfilled when server has started
    public func start(responder: HBHTTPResponder) -> EventLoopFuture<Void> {
        func childChannelInitializer(channel: Channel) -> EventLoopFuture<Void> {
            let tlsChannelHandler = self.tlsChannelHandler?()
            return channel.pipeline.addHandlers(tlsChannelHandler.map { [$0] } ?? []).flatMap {
                let childHandlers = self.getChildChannelHandlers(responder: responder)
                return self.httpChannelInitializer.initialize(channel: channel, childHandlers: childHandlers, configuration: self.configuration)
            }
        }

        let quiesce = ServerQuiescingHelper(group: self.eventLoopGroup)
        self.quiesce = quiesce

        let bootstrap = ServerBootstrap(group: self.eventLoopGroup)
            // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.backlog, value: numericCast(self.configuration.backlog))
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: self.configuration.reuseAddress ? 1 : 0)
            .serverChannelOption(ChannelOptions.tcpOption(.tcp_nodelay), value: self.configuration.tcpNoDelay ? 1 : 0)
            .serverChannelInitializer { channel in
                channel.pipeline.addHandler(quiesce.makeServerChannelHandler(channel: channel))
            }
            // Set the handlers that are applied to the accepted Channels
            .childChannelInitializer(childChannelInitializer)

            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: self.configuration.reuseAddress ? 1 : 0)
            .childChannelOption(ChannelOptions.tcpOption(.tcp_nodelay), value: self.configuration.tcpNoDelay ? 1 : 0)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
            .childChannelOption(ChannelOptions.allowRemoteHalfClosure, value: true)

        let bindFuture: EventLoopFuture<Void>
        switch self.configuration.address {
        case .hostname(let host, let port):
            bindFuture = bootstrap.bind(host: host, port: port)
                .map { channel in
                    self.channel = channel
                    responder.logger.info("Server started and listening on \(host):\(port)")
                }
        case .unixDomainSocket(let path):
            bindFuture = bootstrap.bind(unixDomainSocketPath: path)
                .map { channel in
                    self.channel = channel
                    responder.logger.info("Server started and listening on socket path \(path)")
                }
        }

        return bindFuture
            .flatMapErrorThrowing { error in
                quiesce.initiateShutdown(promise: nil)
                self.quiesce = nil
                throw error
            }
    }

    /// Stop HTTP server
    /// - Returns: EventLoopFuture that is fulfilled when server has stopped
    public func stop() -> EventLoopFuture<Void> {
        let promise = self.eventLoopGroup.next().makePromise(of: Void.self)
        if let quiesce = self.quiesce {
            quiesce.initiateShutdown(promise: promise)
            self.quiesce = nil
        } else {
            promise.succeed(())
        }
        return promise.futureResult.map { _ in self.channel = nil }
    }

    /// Wait on server. This won't return until `stop` has been called
    /// - Throws: `Error.serverNotRunning` if server hasn't fully started
    public func wait() throws {
        guard let channel = self.channel else { throw Error.serverNotRunning }
        try channel.closeFuture.wait()
    }

    /// Return array of child handlers added after HTTP handlers. Used by HBApplication.xct
    /// - Parameter responder: final responder to user
    public func getChildChannelHandlers(responder: HBHTTPResponder) -> [RemovableChannelHandler] {
        return self.childChannelHandlers.getHandlers() + [
            HBHTTPEncodeHandler(configuration: self.configuration),
            HBHTTPDecodeHandler(configuration: self.configuration),
            HBHTTPServerHandler(responder: responder),
        ]
    }

    /// list of child channel handlers
    private var childChannelHandlers: HBHTTPChannelHandlers
    private var tlsChannelHandler: (() -> RemovableChannelHandler)?
}

extension HBHTTPServer {
    /// HTTP server configuration
    public struct Configuration {
        /// Bind address for server
        public let address: HBBindAddress
        /// Server name to return in "server" header
        public let serverName: String?
        /// Maximum upload size allowed
        public let maxUploadSize: Int
        /// Maximum size of buffer for streaming request payloads
        public let maxStreamingBufferSize: Int
        /// Defines the maximum length for the queue of pending connections
        public let backlog: Int
        /// Allows socket to be bound to an address that is already in use.
        public let reuseAddress: Bool
        /// Disables the Nagle algorithm for send coalescing.
        public let tcpNoDelay: Bool
        /// Pipelining ensures that only one http request is processed at one time
        public let withPipeliningAssistance: Bool

        /// Initialize HTTP server configuration
        /// - Parameters:
        ///   - address: Bind address for server
        ///   - serverName: Server name to return in "server" header
        ///   - maxUploadSize: Maximum upload size allowed
        ///   - maxStreamingBufferSize: Maximum size of buffer for streaming request payloads
        ///   - reuseAddress: Allows socket to be bound to an address that is already in use.
        ///   - tcpNoDelay: Disables the Nagle algorithm for send coalescing.
        ///   - withPipeliningAssistance: Pipelining ensures that only one http request is processed at one time
        public init(
            address: HBBindAddress = .hostname(),
            serverName: String? = nil,
            maxUploadSize: Int = 2 * 1024 * 1024,
            maxStreamingBufferSize: Int = 1 * 1024 * 1024,
            backlog: Int = 256,
            reuseAddress: Bool = true,
            tcpNoDelay: Bool = true,
            withPipeliningAssistance: Bool = true
        ) {
            self.address = address
            self.serverName = serverName
            self.maxUploadSize = maxUploadSize
            self.maxStreamingBufferSize = maxStreamingBufferSize
            self.backlog = backlog
            self.reuseAddress = reuseAddress
            self.tcpNoDelay = tcpNoDelay
            self.withPipeliningAssistance = withPipeliningAssistance
        }
    }
}
