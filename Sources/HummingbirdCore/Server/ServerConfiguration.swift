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

/// HTTP server configuration
public struct HBServerConfiguration: Sendable {
    /// Bind address for server
    public let address: HBAddress
    /// Server name to return in "server" header
    public let serverName: String?
    /// Defines the maximum length for the queue of pending connections
    public let backlog: Int
    /// Allows socket to be bound to an address that is already in use.
    public let reuseAddress: Bool
    #if canImport(Network)
    /// TLS options for NIO Transport services
    public let tlsOptions: TSTLSOptions
    #endif

    /// Initialize server configuration
    /// - Parameters:
    ///   - address: Bind address for server
    ///   - serverName: Server name to return in "server" header
    ///   - backlog: the maximum length for the queue of pending connections.  If a connection request arrives with the queue full,
    ///         the client may receive an error with an indication of ECONNREFUSE
    ///   - reuseAddress: Allows socket to be bound to an address that is already in use.
    public init(
        address: HBAddress = .hostname(),
        serverName: String? = nil,
        backlog: Int = 256,
        reuseAddress: Bool = true
    ) {
        self.address = address
        self.serverName = serverName
        self.backlog = backlog
        self.reuseAddress = reuseAddress
        #if canImport(Network)
        self.tlsOptions = .none
        #endif
    }

    /// Initialize HTTP server configuration
    /// - Parameters:
    ///   - address: Bind address for server
    ///   - serverName: Server name to return in "server" header
    ///   - backlog: the maximum length for the queue of pending connections.  If a connection request arrives with the queue full,
    ///         the client may receive an error with an indication of ECONNREFUSE
    ///   - reuseAddress: Allows socket to be bound to an address that is already in use.
    ///   - tlsOptions: TLS options for when you are using NIOTransportServices
    #if canImport(Network)
    public init(
        address: HBAddress = .hostname(),
        serverName: String? = nil,
        backlog: Int = 256,
        reuseAddress: Bool = true,
        tlsOptions: TSTLSOptions
    ) {
        self.address = address
        self.serverName = serverName
        self.backlog = backlog
        self.reuseAddress = reuseAddress
        self.tlsOptions = tlsOptions
    }
    #endif
}
