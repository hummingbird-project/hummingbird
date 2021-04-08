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
import NIOSSL

extension HBHTTPServer {
    /// Add HTTP2 secure upgrade handler
    ///
    /// HTTP2 secure upgrade requires a TLS connection so this will add a TLS handler as well. Do not call `addTLS()` inconjunction with this as
    /// you will then be adding two TLS handlers.
    ///
    /// - Parameter tlsConfiguration: TLS configuration
    @discardableResult public func addHTTP2Upgrade(tlsConfiguration: TLSConfiguration) throws -> HBHTTPServer {
        var tlsConfiguration = tlsConfiguration
        tlsConfiguration.applicationProtocols.append("h2")
        tlsConfiguration.applicationProtocols.append("http/1.1")
        let sslContext = try NIOSSLContext(configuration: tlsConfiguration)

        self.httpChannelInitializer = HTTP2UpgradeChannelInitializer()
        return self.addTLSChannelHandler(NIOSSLServerHandler(context: sslContext))
    }
}
