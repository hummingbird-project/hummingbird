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

/// Address to bind server to
public enum HBBindAddress: Sendable {
    /// bind address define by host and port
    case hostname(_ host: String = "127.0.0.1", port: Int = 8080)
    /// bind address defined by unxi domain socket
    case unixDomainSocket(path: String)

    /// if address is hostname and port return port
    public var port: Int? {
        guard case .hostname(_, let port) = self else { return nil }
        return port
    }

    /// if address is hostname and port return hostname
    public var host: String? {
        guard case .hostname(let host, _) = self else { return nil }
        return host
    }

    /// if address is unix domain socket return unix domain socket path
    public var unixDomainSocketPath: String? {
        guard case .unixDomainSocket(let path) = self else { return nil }
        return path
    }
}
