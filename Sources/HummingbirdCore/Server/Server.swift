//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Logging
import NIOCore
import NIOExtras
import NIOHTTP1
import NIOPosix
#if canImport(Network)
import Network
import NIOTransportServices
#endif
import ServiceLifecycle

/// HTTP server class
public actor HBServer<ChannelSetup: HBChannelSetup>: Service {
    public typealias AsyncChildChannel = ChannelSetup.Value
    public typealias AsyncServerChannel = NIOAsyncChannel<AsyncChildChannel, Never>
    enum State: CustomStringConvertible {
        case initial(
            childChannelSetup: ChannelSetup,
            configuration: HBServerConfiguration,
            onServerRunning: (@Sendable (Channel) async -> Void)?
        )
        case starting
        case running(
            asyncChannel: AsyncServerChannel,
            quiescingHelper: ServerQuiescingHelper
        )
        case shuttingDown(shutdownPromise: EventLoopPromise<Void>)
        case shutdown

        var description: String {
            switch self {
            case .initial:
                return "initial"
            case .starting:
                return "starting"
            case .running:
                return "running"
            case .shuttingDown:
                return "shuttingDown"
            case .shutdown:
                return "shutdown"
            }
        }
    }

    var state: State {
        didSet { self.logger.trace("Server State: \(self.state)") }
    }

    /// Logger used by Server
    public nonisolated let logger: Logger
    let eventLoopGroup: EventLoopGroup

    /// HTTP server errors
    public enum Error: Swift.Error {
        case serverShuttingDown
        case serverShutdown
    }

    /// Initialize Server
    /// - Parameters:
    ///   - group: EventLoopGroup server uses
    ///   - configuration: Configuration for server
    public init(
        childChannelSetup: ChannelSetup,
        configuration: HBServerConfiguration,
        onServerRunning: (@Sendable (Channel) async -> Void)? = { _ in },
        eventLoopGroup: EventLoopGroup,
        logger: Logger
    ) {
        self.state = .initial(
            childChannelSetup: childChannelSetup,
            configuration: configuration,
            onServerRunning: onServerRunning
        )
        self.eventLoopGroup = eventLoopGroup
        self.logger = logger
    }

    public func run() async throws {
        switch self.state {
        case .initial(let childChannelSetup, let configuration, let onServerRunning):
            self.state = .starting

            do {
                let (asyncChannel, quiescingHelper) = try await self.makeServer(
                    childChannelSetup: childChannelSetup,
                    configuration: configuration
                )

                // We have to check our state again since we just awaited on the line above
                switch self.state {
                case .initial, .running:
                    fatalError("We should only be running once")

                case .starting:
                    self.state = .running(asyncChannel: asyncChannel, quiescingHelper: quiescingHelper)

                    await withGracefulShutdownHandler {
                        await onServerRunning?(asyncChannel.channel)

                        // We can now start to handle our work.
                        await withDiscardingTaskGroup { group in
                            do {
                                try await asyncChannel.executeThenClose { inbound in 
                                        for try await childChannel in inbound {
                                            group.addTask {
                                                await childChannelSetup.handle(value: childChannel, logger: self.logger)
                                            }
                                        }
                                }
                            } catch {
                                self.logger.error("Waiting on child channel: \(error)")
                            }
                        }
                    } onGracefulShutdown: {
                        Task {
                            do {
                                try await self.shutdownGracefully()
                            } catch {
                                self.logger.error("Server shutdown error: \(error)")
                            }
                        }
                    }

                case .shuttingDown, .shutdown:
                    try await asyncChannel.channel.close()
                }
            } catch {
                self.state = .shutdown
                throw error
            }
        case .starting, .running:
            fatalError("Run should only be called once")

        case .shuttingDown:
            throw Error.serverShuttingDown

        case .shutdown:
            throw Error.serverShutdown
        }
    }

    /// Stop HTTP server
    public func shutdownGracefully() async throws {
        switch self.state {
        case .initial, .starting:
            self.state = .shutdown

        case .running(let channel, let quiescingHelper):
            // quiesce open channels
            let shutdownPromise = channel.channel.eventLoop.makePromise(of: Void.self)
            self.state = .shuttingDown(shutdownPromise: shutdownPromise)
            quiescingHelper.initiateShutdown(promise: shutdownPromise)
            try await shutdownPromise.futureResult.get()

            // We need to check the state here again since we just awaited above
            switch self.state {
            case .initial, .starting, .running, .shutdown:
                fatalError("Unexpected state")

            case .shuttingDown:
                self.state = .shutdown
            }

        case .shuttingDown(let shutdownPromise):
            // We are just going to queue up behind the current graceful shutdown
            try await shutdownPromise.futureResult.get()

        case .shutdown:
            return
        }
    }

    /// Start server
    /// - Parameter responder: Object that provides responses to requests sent to the server
    /// - Returns: EventLoopFuture that is fulfilled when server has started
    public func makeServer(childChannelSetup: ChannelSetup, configuration: HBServerConfiguration) async throws -> (AsyncServerChannel, ServerQuiescingHelper) {
        let quiescingHelper = ServerQuiescingHelper(group: self.eventLoopGroup)
        let bootstrap: ServerBootstrapProtocol
        #if canImport(Network)
        if let tsBootstrap = self.createTSBootstrap(
            configuration: configuration,
            quiescingHelper: quiescingHelper
        ) {
            bootstrap = tsBootstrap
        } else {
            #if os(iOS) || os(tvOS)
            self.logger.warning("Running BSD sockets on iOS or tvOS is not recommended. Please use NIOTSEventLoopGroup, to run with the Network framework")
            #endif
            if configuration.tlsOptions.options != nil {
                self.logger.warning("tlsOptions set in Configuration will not be applied to a BSD sockets server. Please use NIOTSEventLoopGroup, to run with the Network framework")
            }
            bootstrap = self.createSocketsBootstrap(
                configuration: configuration,
                quiescingHelper: quiescingHelper
            )
        }
        #else
        bootstrap = self.createSocketsBootstrap(
            configuration: configuration,
            quiescingHelper: quiescingHelper
        )
        #endif

        do {
            let asyncChannel: AsyncServerChannel
            switch configuration.address {
            case .hostname(let host, let port):
                asyncChannel = try await bootstrap.bind(
                    host: host,
                    port: port,
                    serverBackPressureStrategy: nil
                ) { channel in
                    childChannelSetup.initialize(
                        channel: channel,
                        configuration: configuration,
                        logger: self.logger
                    )
                }
                self.logger.info("Server started and listening on \(host):\(port)")
            case .unixDomainSocket(let path):
                asyncChannel = try await bootstrap.bind(
                    unixDomainSocketPath: path,
                    cleanupExistingSocketFile: false,
                    serverBackPressureStrategy: nil
                ) { channel in
                    childChannelSetup.initialize(
                        channel: channel,
                        configuration: configuration,
                        logger: self.logger
                    )
                }
                self.logger.info("Server started and listening on socket path \(path)")
            }
            return (asyncChannel, quiescingHelper)
        } catch {
            quiescingHelper.initiateShutdown(promise: nil)
            throw error
        }
    }

    /// create a BSD sockets based bootstrap
    private func createSocketsBootstrap(
        configuration: HBServerConfiguration,
        quiescingHelper: ServerQuiescingHelper
    ) -> ServerBootstrap {
        return ServerBootstrap(group: self.eventLoopGroup)
            // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.backlog, value: numericCast(configuration.backlog))
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: configuration.reuseAddress ? 1 : 0)
            .serverChannelInitializer { channel in
                channel.pipeline.addHandler(quiescingHelper.makeServerChannelHandler(channel: channel))
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: configuration.reuseAddress ? 1 : 0)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
            .childChannelOption(ChannelOptions.allowRemoteHalfClosure, value: true)
    }

    #if canImport(Network)
    /// create a NIOTransportServices bootstrap using Network.framework
    @available(macOS 10.14, iOS 12, tvOS 12, *)
    private func createTSBootstrap(
        configuration: HBServerConfiguration,
        quiescingHelper: ServerQuiescingHelper
    ) -> NIOTSListenerBootstrap? {
        guard let bootstrap = NIOTSListenerBootstrap(validatingGroup: self.eventLoopGroup)?
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: configuration.reuseAddress ? 1 : 0)
            .serverChannelInitializer({ channel in
                channel.pipeline.addHandler(quiescingHelper.makeServerChannelHandler(channel: channel))
            })
            // Set the handlers that are applied to the accepted Channels
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: configuration.reuseAddress ? 1 : 0)
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
}

/// Protocol for bootstrap.
protocol ServerBootstrapProtocol {
    func bind<Output: Sendable>(
        host: String,
        port: Int,
        serverBackPressureStrategy: NIOAsyncSequenceProducerBackPressureStrategies.HighLowWatermark?,
        childChannelInitializer: @escaping @Sendable (Channel) -> EventLoopFuture<Output>
    ) async throws -> NIOAsyncChannel<Output, Never>

    func bind<Output: Sendable>(
        unixDomainSocketPath: String,
        cleanupExistingSocketFile: Bool,
        serverBackPressureStrategy: NIOAsyncSequenceProducerBackPressureStrategies.HighLowWatermark?,
        childChannelInitializer: @escaping @Sendable (Channel) -> EventLoopFuture<Output>
    ) async throws -> NIOAsyncChannel<Output, Never>
}

// Extend both `ServerBootstrap` and `NIOTSListenerBootstrap` to conform to `ServerBootstrapProtocol`
extension ServerBootstrap: ServerBootstrapProtocol {}

#if canImport(Network)
@available(macOS 10.14, iOS 12, tvOS 12, *)
extension NIOTSListenerBootstrap: ServerBootstrapProtocol {
    // need to be able to extend `NIOTSListenerBootstrap` to conform to `ServerBootstrapProtocol`
    // before we can use TransportServices
    func bind<Output: Sendable>(
        unixDomainSocketPath: String,
        cleanupExistingSocketFile: Bool,
        serverBackPressureStrategy: NIOAsyncSequenceProducerBackPressureStrategies.HighLowWatermark?,
        childChannelInitializer: @escaping @Sendable (Channel) -> EventLoopFuture<Output>
    ) async throws -> NIOAsyncChannel<Output, Never> {
        preconditionFailure("Binding to a unixDomainSocketPath is currently not available")
    }
}
#endif

extension HBServer: CustomStringConvertible {
    public nonisolated var description: String {
        "Hummingbird"
    }
}
