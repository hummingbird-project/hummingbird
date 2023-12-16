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
public struct HBApplicationConfiguration: Sendable {
    // MARK: Member variables

    /// Bind address for server
    public let address: HBBindAddress
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
    ///   - backlog: the maximum length for the queue of pending connections.  If a connection request arrives with the queue full,
    ///         the client may receive an error with an indication of ECONNREFUSE
    ///   - reuseAddress: Allows socket to be bound to an address that is already in use.
    ///   - logLevel: Logging level
    ///   - noHTTPServer: Don't start up the HTTP server.
    public init(
        address: HBBindAddress = .hostname(),
        serverName: String? = nil,
        backlog: Int = 256,
        reuseAddress: Bool = true,
        threadPoolSize: Int = 2,
        logLevel: Logger.Level? = nil,
        noHTTPServer: Bool = false
    ) {
        let env = HBEnvironment()

        self.address = address
        self.serverName = serverName
        self.backlog = backlog
        self.reuseAddress = reuseAddress
        #if canImport(Network)
        self.tlsOptions = .none
        #endif

        self.noHTTPServer = noHTTPServer

        if let logLevel {
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
    ///   - reuseAddress: Allows socket to be bound to an address that is already in use.
    ///   - logLevel: Logging level
    ///   - noHTTPServer: Don't start up the HTTP server.
    ///   - tlsOptions: TLS options for when you are using NIOTransportServices
    public init(
        address: HBBindAddress = .hostname(),
        serverName: String? = nil,
        reuseAddress: Bool = true,
        logLevel: Logger.Level? = nil,
        noHTTPServer: Bool = false,
        tlsOptions: TSTLSOptions
    ) {
        let env = HBEnvironment()

        self.address = address
        self.serverName = serverName
        self.backlog = 256 // not used by Network framework
        self.reuseAddress = reuseAddress
        self.tlsOptions = tlsOptions

        self.noHTTPServer = noHTTPServer

        if let logLevel {
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
        backlog: Int? = nil,
        reuseAddress: Bool? = nil,
        logLevel: Logger.Level? = nil
    ) -> Self {
        return .init(
            address: address ?? self.address,
            serverName: serverName ?? self.serverName,
            backlog: backlog ?? self.backlog,
            reuseAddress: reuseAddress ?? self.reuseAddress,
            logLevel: logLevel ?? self.logLevel
        )
    }

    /// return HTTP server configuration
    #if canImport(Network)
    var httpServer: HBServerConfiguration {
        return .init(
            address: self.address,
            serverName: self.serverName,
            backlog: self.backlog,
            reuseAddress: self.reuseAddress,
            tlsOptions: self.tlsOptions
        )
    }
    #else
    var httpServer: HBServerConfiguration {
        return .init(
            address: self.address,
            serverName: self.serverName,
            backlog: self.backlog,
            reuseAddress: self.reuseAddress
        )
    }
    #endif
}
