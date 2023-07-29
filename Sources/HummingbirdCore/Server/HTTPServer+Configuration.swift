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

extension HBHTTPServer {
    /// Idle state handlder configuration
    public struct IdleStateHandlerConfiguration: Sendable {
        /// timeout when reading a request
        let readTimeout: TimeAmount
        /// timeout since last writing a response
        let writeTimeout: TimeAmount

        public init(readTimeout: TimeAmount = .seconds(30), writeTimeout: TimeAmount = .minutes(3)) {
            self.readTimeout = readTimeout
            self.writeTimeout = writeTimeout
        }
    }

    /// HTTP server configuration
    public struct Configuration: Sendable {
        /// Bind address for server
        public let address: HBBindAddress
        /// Server name to return in "server" header
        public let serverName: String?
        /// Maximum upload size allowed
        public let maxUploadSize: Int
        /// Maximum size of data in flight while streaming request payloads before back pressure is applied.
        public let maxStreamingBufferSize: Int
        /// Defines the maximum length for the queue of pending connections
        public let backlog: Int
        /// Allows socket to be bound to an address that is already in use.
        public let reuseAddress: Bool
        /// Disables the Nagle algorithm for send coalescing.
        public let tcpNoDelay: Bool
        /// Pipelining ensures that only one http request is processed at one time
        public let withPipeliningAssistance: Bool
        #if canImport(Network)
        /// TLS options for NIO Transport services
        public let tlsOptions: TSTLSOptions
        #endif

        /// Initialize HTTP server configuration
        /// - Parameters:
        ///   - address: Bind address for server
        ///   - serverName: Server name to return in "server" header
        ///   - maxUploadSize: Maximum upload size allowed
        ///   - maxStreamingBufferSize: Maximum size of data in flight while streaming request payloads before back pressure is applied.
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
            #if canImport(Network)
            self.tlsOptions = .none
            #endif
        }

        /// Initialize HTTP server configuration
        /// - Parameters:
        ///   - address: Bind address for server
        ///   - serverName: Server name to return in "server" header
        ///   - maxUploadSize: Maximum upload size allowed
        ///   - maxStreamingBufferSize: Maximum size of data in flight while streaming request payloads before back pressure is applied.
        ///   - reuseAddress: Allows socket to be bound to an address that is already in use.
        ///   - withPipeliningAssistance: Pipelining ensures that only one http request is processed at one time
        ///   - tlsOptions: TLS options for when you are using NIOTransportServices
        #if canImport(Network)
        public init(
            address: HBBindAddress = .hostname(),
            serverName: String? = nil,
            maxUploadSize: Int = 2 * 1024 * 1024,
            maxStreamingBufferSize: Int = 1 * 1024 * 1024,
            reuseAddress: Bool = true,
            withPipeliningAssistance: Bool = true,
            tlsOptions: TSTLSOptions
        ) {
            self.address = address
            self.serverName = serverName
            self.maxUploadSize = maxUploadSize
            self.maxStreamingBufferSize = maxStreamingBufferSize
            self.backlog = 256
            self.reuseAddress = reuseAddress
            self.tcpNoDelay = true
            self.withPipeliningAssistance = withPipeliningAssistance
            self.tlsOptions = tlsOptions
        }
        #endif
    }
}
