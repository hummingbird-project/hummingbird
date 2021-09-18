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
import NIOExtras
import NIOHTTP1
import NIOPosix
#if canImport(Network)
import Network
import NIOTransportServices
#endif

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
        #if canImport(Network)
        let bootstrap: HTTPServerBootstrap
        if #available(macOS 10.14, iOS 12, tvOS 12, *), let tsBootstrap = self.createTSBootstrap(quiesce: quiesce, childChannelInitializer: childChannelInitializer) {
            bootstrap = tsBootstrap
        } else {
            #if os(iOS) || os(tvOS)
            responder.logger.warning("Running BSD sockets on iOS or tvOS is not recommended. Please use NIOTSEventLoopGroup, to run with the Network framework")
            #endif
            if #available(macOS 10.14, iOS 12, tvOS 12, *), self.configuration.tlsOptions.options != nil {
                responder.logger.warning("tlsOptions set in Configuration will not be applied to a BSD sockets server. Please use NIOTSEventLoopGroup, to run with the Network framework")
            }
            bootstrap = self.createSocketsBootstrap(quiesce: quiesce, childChannelInitializer: childChannelInitializer)
        }
        #else
        let bootstrap = self.createSocketsBootstrap(quiesce: quiesce, childChannelInitializer: childChannelInitializer)
        #endif

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

    public var port: Int? {
        if self.channel != nil {
            return self.channel?.localAddress?.port
        } else if self.configuration.address.port != 0 {
            return self.configuration.address.port
        }
        return nil
    }

    /// create a BSD sockets based bootstrap
    private func createSocketsBootstrap(quiesce: ServerQuiescingHelper, childChannelInitializer: @escaping (Channel) -> EventLoopFuture<Void>) -> HTTPServerBootstrap {
        return ServerBootstrap(group: self.eventLoopGroup)
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
    }

    #if canImport(Network)
    /// create a NIOTransportServices bootstrap using Network.framework
    @available(macOS 10.14, iOS 12, tvOS 12, *)
    private func createTSBootstrap(quiesce: ServerQuiescingHelper, childChannelInitializer: @escaping (Channel) -> EventLoopFuture<Void>) -> HTTPServerBootstrap? {
        guard let bootstrap = NIOTSListenerBootstrap(validatingGroup: self.eventLoopGroup)?
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: self.configuration.reuseAddress ? 1 : 0)
            .serverChannelInitializer({ channel in
                channel.pipeline.addHandler(quiesce.makeServerChannelHandler(channel: channel))
            })
            // Set the handlers that are applied to the accepted Channels
            .childChannelInitializer(childChannelInitializer)
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: self.configuration.reuseAddress ? 1 : 0)
            .childChannelOption(ChannelOptions.allowRemoteHalfClosure, value: true)
        else {
            return nil
        }

        if let tlsOptions = configuration.tlsOptions.options {
            return bootstrap.tlsOptions(tlsOptions)
        }
        return bootstrap
    }
    #endif

    /// list of child channel handlers
    private var childChannelHandlers: HBHTTPChannelHandlers
    private var tlsChannelHandler: (() -> RemovableChannelHandler)?
}

/// Protocol for bootstrap.
protocol HTTPServerBootstrap {
    func bind(host: String, port: Int) -> EventLoopFuture<Channel>
    func bind(unixDomainSocketPath: String) -> EventLoopFuture<Channel>
}

// Extend both `ServerBootstrap` and `NIOTSListenerBootstrap` to conform to `HTTPServerBootstrap`
extension ServerBootstrap: HTTPServerBootstrap {}
#if canImport(Network)
@available(macOS 10.14, iOS 12, tvOS 12, *)
extension NIOTSListenerBootstrap: HTTPServerBootstrap {}
#endif
