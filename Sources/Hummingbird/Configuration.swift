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

import HummingbirdCore
import Logging
#if canImport(Network)
import Network
#endif

extension HBApplication {
    // MARK: Configuration

    /// Application configuration
    public struct Configuration {
        // MARK: Member variables

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
        public let enableHttpPipelining: Bool
        /// Idle state handler setup.
        public let idleTimeoutConfiguration: HBHTTPServer.IdleStateHandlerConfiguration?
        #if canImport(Network)
        /// TLS options for NIO Transport services
        public let tlsOptions: TSTLSOptions
        #endif

        /// Number of threads to allocate in the application thread pool
        public let threadPoolSize: Int
        /// don't run the HTTP server
        public let noHTTPServer: Bool
        /// logging level
        public let logLevel: Logger.Level

        // MARK: Initialization

        /// Initialize HBApplication configuration
        ///
        /// - Parameters:
        ///   - address: Bind address for server
        ///   - serverName: Server name to return in "server" header
        ///   - maxUploadSize: Maximum upload size allowed
        ///   - maxStreamingBufferSize: Maximum size of buffer for streaming request payloads
        ///   - backlog: the maximum length for the queue of pending connections.  If a connection request arrives with the queue full,
        ///         the client may receive an error with an indication of ECONNREFUSE
        ///   - reuseAddress: Allows socket to be bound to an address that is already in use.
        ///   - tcpNoDelay: Disables the Nagle algorithm for send coalescing.
        ///   - enableHttpPipelining: Pipelining ensures that only one http request is processed at one time
        ///   - threadPoolSize: Number of threads in application thread pool
        ///   - logLevel: Logging level
        ///   - noHTTPServer: Don't start up the HTTP server.
        public init(
            address: HBBindAddress = .hostname(),
            serverName: String? = nil,
            maxUploadSize: Int = 2 * 1024 * 1024,
            maxStreamingBufferSize: Int = 1 * 1024 * 1024,
            backlog: Int = 256,
            reuseAddress: Bool = true,
            tcpNoDelay: Bool = false,
            enableHttpPipelining: Bool = true,
            idleTimeoutConfiguration: HBHTTPServer.IdleStateHandlerConfiguration? = nil,
            threadPoolSize: Int = 2,
            logLevel: Logger.Level? = nil,
            noHTTPServer: Bool = false
        ) {
            let env = HBEnvironment()

            self.address = address
            self.serverName = serverName
            self.maxUploadSize = maxUploadSize
            self.maxStreamingBufferSize = maxStreamingBufferSize
            self.backlog = backlog
            self.reuseAddress = reuseAddress
            self.tcpNoDelay = tcpNoDelay
            self.enableHttpPipelining = enableHttpPipelining
            self.idleTimeoutConfiguration = idleTimeoutConfiguration
            #if canImport(Network)
            self.tlsOptions = .none
            #endif

            self.threadPoolSize = threadPoolSize
            self.noHTTPServer = noHTTPServer

            if let logLevel = logLevel {
                self.logLevel = logLevel
            } else if let logLevel = env.get("LOG_LEVEL") {
                self.logLevel = Logger.Level(rawValue: logLevel) ?? .info
            } else {
                self.logLevel = .info
            }
        }

        #if canImport(Network)
        /// Initialize HBApplication configuration
        ///
        /// - Parameters:
        ///   - address: Bind address for server
        ///   - serverName: Server name to return in "server" header
        ///   - maxUploadSize: Maximum upload size allowed
        ///   - maxStreamingBufferSize: Maximum size of buffer for streaming request payloads
        ///   - reuseAddress: Allows socket to be bound to an address that is already in use.
        ///   - enableHttpPipelining: Pipelining ensures that only one http request is processed at one time
        ///   - threadPoolSize: Number of threads in application thread pool
        ///   - logLevel: Logging level
        ///   - noHTTPServer: Don't start up the HTTP server.
        ///   - tlsOptions: TLS options for when you are using NIOTransportServices
        @available(macOS 10.14, iOS 12, tvOS 12, *)
        public init(
            address: HBBindAddress = .hostname(),
            serverName: String? = nil,
            maxUploadSize: Int = 2 * 1024 * 1024,
            maxStreamingBufferSize: Int = 1 * 1024 * 1024,
            reuseAddress: Bool = true,
            enableHttpPipelining: Bool = true,
            idleTimeoutConfiguration: HBHTTPServer.IdleStateHandlerConfiguration? = nil,
            threadPoolSize: Int = 2,
            logLevel: Logger.Level? = nil,
            noHTTPServer: Bool = false,
            tlsOptions: TSTLSOptions
        ) {
            let env = HBEnvironment()

            self.address = address
            self.serverName = serverName
            self.maxUploadSize = maxUploadSize
            self.maxStreamingBufferSize = maxStreamingBufferSize
            self.backlog = 256 // not used by Network framework
            self.reuseAddress = reuseAddress
            self.tcpNoDelay = true // not used by Network framework
            self.enableHttpPipelining = enableHttpPipelining
            self.idleTimeoutConfiguration = idleTimeoutConfiguration
            self.tlsOptions = tlsOptions

            self.threadPoolSize = threadPoolSize
            self.noHTTPServer = noHTTPServer

            if let logLevel = logLevel {
                self.logLevel = logLevel
            } else if let logLevel = env.get("LOG_LEVEL") {
                self.logLevel = Logger.Level(rawValue: logLevel) ?? .info
            } else {
                self.logLevel = .info
            }
        }
        #endif

        /// Create new configuration struct with updated values
        public func with(
            address: HBBindAddress? = nil,
            serverName: String? = nil,
            maxUploadSize: Int? = nil,
            maxStreamingBufferSize: Int? = nil,
            backlog: Int? = nil,
            reuseAddress: Bool? = nil,
            tcpNoDelay: Bool? = nil,
            enableHttpPipelining: Bool? = nil,
            idleTimeoutConfiguration: HBHTTPServer.IdleStateHandlerConfiguration? = nil,
            threadPoolSize: Int? = nil,
            logLevel: Logger.Level? = nil
        ) -> Self {
            return Configuration(
                address: address ?? self.address,
                serverName: serverName ?? self.serverName,
                maxUploadSize: maxUploadSize ?? self.maxUploadSize,
                maxStreamingBufferSize: maxStreamingBufferSize ?? self.maxStreamingBufferSize,
                backlog: backlog ?? self.backlog,
                reuseAddress: reuseAddress ?? self.reuseAddress,
                tcpNoDelay: tcpNoDelay ?? self.tcpNoDelay,
                enableHttpPipelining: enableHttpPipelining ?? self.enableHttpPipelining,
                idleTimeoutConfiguration: idleTimeoutConfiguration ?? self.idleTimeoutConfiguration,
                threadPoolSize: threadPoolSize ?? self.threadPoolSize,
                logLevel: logLevel ?? self.logLevel
            )
        }

        /// return HTTP server configuration
        #if canImport(Network)
        var httpServer: HBHTTPServer.Configuration {
            return .init(
                address: self.address,
                serverName: self.serverName,
                maxUploadSize: self.maxUploadSize,
                maxStreamingBufferSize: self.maxStreamingBufferSize,
                reuseAddress: self.reuseAddress,
                withPipeliningAssistance: self.enableHttpPipelining,
                idleTimeoutConfiguration: self.idleTimeoutConfiguration,
                tlsOptions: self.tlsOptions
            )
        }
        #else
        var httpServer: HBHTTPServer.Configuration {
            return .init(
                address: self.address,
                serverName: self.serverName,
                maxUploadSize: self.maxUploadSize,
                maxStreamingBufferSize: self.maxStreamingBufferSize,
                backlog: self.backlog,
                reuseAddress: self.reuseAddress,
                tcpNoDelay: self.tcpNoDelay,
                withPipeliningAssistance: self.enableHttpPipelining,
                idleTimeoutConfiguration: self.idleTimeoutConfiguration
            )
        }
        #endif
    }
}
