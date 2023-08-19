//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Dispatch
import HummingbirdCore
import Logging
import NIOCore
import NIOHTTP1
import NIOPosix
import NIOTransportServices
import ServiceLifecycle

public struct HBApplication: Sendable {
    public struct Context: Sendable {
        /// thread pool used by application
        public let threadPool: NIOThreadPool
        /// Configuration
        public let configuration: Configuration
        /// Logger. Required to be a var by hummingbird-lambda
        public let logger: Logger
        /// Encoder used by router
        public let encoder: HBResponseEncoder
        /// decoder used by router
        public let decoder: HBRequestDecoder

        public init(
            threadPool: NIOThreadPool,
            configuration: Configuration,
            logger: Logger,
            encoder: HBResponseEncoder,
            decoder: HBRequestDecoder
        ) {
            self.threadPool = threadPool
            self.configuration = configuration
            self.logger = logger
            self.encoder = encoder
            self.decoder = decoder
        }
    }

    /// event loop group used by application
    public let context: Context
    // eventLoopGroup
    public let eventLoopGroup: EventLoopGroup
    // server
    public let server: HBHTTPServer
    // date cache service
    public let dateCache: HBDateCache

    init(builder: HBApplicationBuilder) {
        self.eventLoopGroup = builder.eventLoopGroup
        self.context = .init(
            threadPool: builder.threadPool,
            configuration: builder.configuration,
            logger: builder.logger,
            encoder: builder.encoder,
            decoder: builder.decoder
        )
        self.dateCache = .init()
        let responder = Responder(
            responder: builder.constructResponder(),
            applicationContext: self.context,
            dateCache: self.dateCache
        )
        self.server = HBHTTPServer(
            group: builder.eventLoopGroup,
            configuration: builder.configuration.httpServer,
            responder: responder,
            additionalChannelHandlers: builder.additionalChannelHandlers.map { $0() },
            onServerRunning: builder.onServerRunning,
            logger: builder.logger
        )
    }

    /// shutdown eventloop, threadpool and any extensions attached to the Application
    public func shutdownApplication() throws {
        try self.context.threadPool.syncShutdownGracefully()
    }
}

/// Conform to `Service` from `ServiceLifecycle`.
/// TODO: Temporarily I have added unchecked Sendable conformance to the class as Sendable
/// conformance is required by `Service`. I will need to revisit this.
extension HBApplication: Service {
    public func run() async throws {
        try await withGracefulShutdownHandler {
            let services: [any Service] = [self.server, self.dateCache]
            let serviceGroup = ServiceGroup(
                configuration: .init(services: services, logger: self.context.logger)
            )
            try await serviceGroup.run()
            try self.shutdownApplication()
        } onGracefulShutdown: {
            Task {
                try await self.server.shutdownGracefully()
            }
        }
    }
}

extension HBApplication: CustomStringConvertible {
    public var description: String { "HBApplication" }
}
