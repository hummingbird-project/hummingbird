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

import HummingbirdCore
import Logging
import NIOCore
#if canImport(Network)
import Network
#endif

// MARK: Configuration

/// Application configuration
public struct ApplicationConfiguration: Sendable {
    // MARK: Member variables

    /// Bind address for server
    public var address: BindAddress
    /// Server name to return in "server" header
    public var serverName: String?
    /// Defines the maximum length for the queue of pending connections
    public var backlog: Int
    /// Allows socket to be bound to an address that is already in use.
    public var reuseAddress: Bool
    /// Maximum active connections
    public let availableConnectionDelegate: AvailableConnectionsDelegate?
    #if canImport(Network)
    /// TLS options for NIO Transport services
    public var tlsOptions: TSTLSOptions
    #endif

    // MARK: Initialization

    /// Initialize Application configuration
    ///
    /// - Parameters:
    ///   - address: Bind address for server
    ///   - serverName: Server name to return in "server" header
    ///   - backlog: the maximum length for the queue of pending connections.  If a connection request arrives with the queue full,
    ///         the client may receive an error with an indication of ECONNREFUSE
    ///   - reuseAddress: Allows socket to be bound to an address that is already in use.
    public init(
        address: BindAddress = .hostname(),
        serverName: String? = nil,
        backlog: Int = 256,
        reuseAddress: Bool = true,
        availableConnectionDelegate: AvailableConnectionsDelegate? = nil
    ) {
        self.address = address
        self.serverName = serverName
        self.backlog = backlog
        self.reuseAddress = reuseAddress
        self.availableConnectionDelegate = availableConnectionDelegate
        #if canImport(Network)
        self.tlsOptions = .none
        #endif
    }

    #if canImport(Network)
    /// Initialize Application configuration
    ///
    /// - Parameters:
    ///   - address: Bind address for server
    ///   - serverName: Server name to return in "server" header
    ///   - reuseAddress: Allows socket to be bound to an address that is already in use.
    ///   - tlsOptions: TLS options for when you are using NIOTransportServices
    public init(
        address: BindAddress = .hostname(),
        serverName: String? = nil,
        reuseAddress: Bool = true,
        availableConnectionDelegate: AvailableConnectionsDelegate? = nil,
        tlsOptions: TSTLSOptions
    ) {
        self.address = address
        self.serverName = serverName
        self.backlog = 256 // not used by Network framework
        self.reuseAddress = reuseAddress
        self.availableConnectionDelegate = availableConnectionDelegate
        self.tlsOptions = tlsOptions
    }

    #endif

    /// Create new configuration struct with updated values
    public func with(
        address: BindAddress? = nil,
        serverName: String? = nil,
        backlog: Int? = nil,
        reuseAddress: Bool? = nil
    ) -> Self {
        return .init(
            address: address ?? self.address,
            serverName: serverName ?? self.serverName,
            backlog: backlog ?? self.backlog,
            reuseAddress: reuseAddress ?? self.reuseAddress
        )
    }

    /// return HTTP server configuration
    #if canImport(Network)
    var httpServer: ServerConfiguration {
        return .init(
            address: self.address,
            serverName: self.serverName,
            backlog: self.backlog,
            reuseAddress: self.reuseAddress,
            availableConnectionDelegate: self.availableConnectionDelegate,
            tlsOptions: self.tlsOptions
        )
    }
    #else
    var httpServer: ServerConfiguration {
        return .init(
            address: self.address,
            serverName: self.serverName,
            backlog: self.backlog,
            reuseAddress: self.reuseAddress,
            availableConnectionDelegate: self.availableConnectionDelegate
        )
    }
    #endif
}
