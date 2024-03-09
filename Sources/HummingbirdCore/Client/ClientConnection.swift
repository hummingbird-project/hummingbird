//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2024 the Hummingbird authors
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
import NIOPosix
import ServiceLifecycle
#if canImport(Network)
import Network
import NIOTransportServices
#endif

/// A generic client connection to a server.
///
/// Actual client protocol is implemented in `ClientChannel` generic parameter
public struct ClientConnection<ClientChannel: ClientConnectionChannel>: Sendable {
    typealias ChannelResult = ClientChannel.Value
    /// Logger used by Server
    let logger: Logger
    let eventLoopGroup: EventLoopGroup
    let clientChannel: ClientChannel
    let address: Address
    #if canImport(Network)
    let tlsOptions: NWProtocolTLS.Options?
    #endif

    /// Initialize Client
    public init(
        _ clientChannel: ClientChannel,
        address: Address,
        eventLoopGroup: EventLoopGroup = MultiThreadedEventLoopGroup.singleton,
        logger: Logger
    ) {
        self.clientChannel = clientChannel
        self.address = address
        self.eventLoopGroup = eventLoopGroup
        self.logger = logger
        #if canImport(Network)
        self.tlsOptions = nil
        #endif
    }

    #if canImport(Network)
    /// Initialize Client with TLS options
    public init(
        _ clientChannel: ClientChannel,
        address: Address,
        transportServicesTLSOptions: TSTLSOptions,
        eventLoopGroup: EventLoopGroup = MultiThreadedEventLoopGroup.singleton,
        logger: Logger
    ) throws {
        self.clientChannel = clientChannel
        self.address = address
        self.eventLoopGroup = eventLoopGroup
        self.logger = logger
        self.tlsOptions = transportServicesTLSOptions.options
    }
    #endif

    public func run() async throws {
        let channelResult = try await self.makeClient(
            clientChannel: self.clientChannel,
            address: self.address
        )
        try await self.clientChannel.handle(value: channelResult, logger: self.logger)
    }

    /// Connect to server
    func makeClient(clientChannel: ClientChannel, address: Address) async throws -> ChannelResult {
        // get bootstrap
        let bootstrap: ClientBootstrapProtocol
        #if canImport(Network)
        if let tsBootstrap = self.createTSBootstrap() {
            bootstrap = tsBootstrap
        } else {
            #if os(iOS) || os(tvOS)
            self.logger.warning("Running BSD sockets on iOS or tvOS is not recommended. Please use NIOTSEventLoopGroup, to run with the Network framework")
            #endif
            bootstrap = self.createSocketsBootstrap()
        }
        #else
        bootstrap = self.createSocketsBootstrap()
        #endif

        // connect
        let result: ChannelResult
        do {
            switch address.value {
            case .hostname(let host, let port):
                result = try await bootstrap
                    .connect(host: host, port: port) { channel in
                        clientChannel.setup(channel: channel, logger: self.logger)
                    }
                self.logger.debug("Client connnected to \(host):\(port)")
            case .unixDomainSocket(let path):
                result = try await bootstrap
                    .connect(unixDomainSocketPath: path) { channel in
                        clientChannel.setup(channel: channel, logger: self.logger)
                    }
                self.logger.debug("Client connnected to socket path \(path)")
            }
            return result
        } catch {
            throw error
        }
    }

    /// create a BSD sockets based bootstrap
    private func createSocketsBootstrap() -> ClientBootstrap {
        return ClientBootstrap(group: self.eventLoopGroup)
    }

    #if canImport(Network)
    /// create a NIOTransportServices bootstrap using Network.framework
    private func createTSBootstrap() -> NIOTSConnectionBootstrap? {
        guard let bootstrap = NIOTSConnectionBootstrap(validatingGroup: self.eventLoopGroup) else {
            return nil
        }
        if let tlsOptions {
            return bootstrap.tlsOptions(tlsOptions)
        }
        return bootstrap
    }
    #endif
}

protocol ClientBootstrapProtocol {
    func connect<Output: Sendable>(
        host: String,
        port: Int,
        channelInitializer: @escaping @Sendable (Channel) -> EventLoopFuture<Output>
    ) async throws -> Output

    func connect<Output: Sendable>(
        unixDomainSocketPath: String,
        channelInitializer: @escaping @Sendable (Channel) -> EventLoopFuture<Output>
    ) async throws -> Output
}

extension ClientBootstrap: ClientBootstrapProtocol {}
#if canImport(Network)
extension NIOTSConnectionBootstrap: ClientBootstrapProtocol {}
#endif
