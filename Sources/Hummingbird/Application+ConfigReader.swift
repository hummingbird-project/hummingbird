//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2025 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if ConfigurationSupport

public import Configuration

@available(macOS 15, iOS 18, macCatalyst 18, tvOS 18, visionOS 2, *)
extension ApplicationConfiguration {
    /// Initialize a ApplicationConfiguration from a ConfigReader
    ///
    /// - Configuration keys:
    ///   - `host` (string, optional, default: "127.0.0.1"): Hostname or IP to bind server to
    ///   - `port` (int, optional, default: 8080): Port to bind server to
    ///   - `unixDomainSocket` (string, optional): Unix domain socket name
    ///   - `serverName` (string, optional): Server name reported in HTTP headers
    ///
    /// - Parameters
    ///   - reader: ConfigReader
    public init(reader: ConfigReader) {
        var configuration = Self()
        let hostname = reader.string(forKey: "host")
        let port = reader.int(forKey: "port")
        if hostname != nil || port != nil {
            configuration.address = .hostname(hostname ?? "127.0.0.1", port: port ?? 8080)
        } else if let unixDomainSocket = reader.string(forKey: "unixDomainSocket") {
            configuration.address = .unixDomainSocket(path: unixDomainSocket)
        }
        if let serverName = reader.string(forKey: "serverName") {
            configuration.serverName = serverName
        }
        self = configuration
    }
}

#endif
