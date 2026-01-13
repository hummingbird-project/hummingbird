//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import HummingbirdCore
import NIOCore
import NIOSSL

extension HTTPServerBuilder {
    /// Build HTTP channel with HTTP2 upgrade
    ///
    /// Use in ``Hummingbird/Application`` initialization.
    /// ```
    /// let app = Application(
    ///     router: router,
    ///     server: .http2Upgrade(tlsConfiguration: tlsConfiguration)
    /// )
    /// ```
    /// - Parameters:
    ///   - tlsConfiguration: TLS configuration
    ///   - additionalChannelHandlers: Additional channel handlers to add to stream channel pipeline after HTTP part decoding and
    ///       before HTTP request handling
    /// - Returns: HTTPChannelHandler builder
    @available(*, deprecated, renamed: "http2Upgrade(tlsConfiguration:configuration:)")
    public static func http2Upgrade(
        tlsConfiguration: TLSConfiguration,
        additionalChannelHandlers: @autoclosure @escaping @Sendable () -> [any RemovableChannelHandler]
    ) throws -> HTTPServerBuilder {
        .init { responder in
            try HTTP2UpgradeChannel(
                tlsConfiguration: tlsConfiguration,
                additionalChannelHandlers: additionalChannelHandlers,
                responder: responder
            )
        }
    }

    /// Build HTTP channel with HTTP2 upgrade
    ///
    /// Use in ``Hummingbird/Application`` initialization.
    /// ```
    /// let app = Application(
    ///     router: router,
    ///     server: .http2Upgrade(configuration: .init(tlsConfiguration: tlsConfiguration))
    /// )
    /// ```
    /// - Parameters:
    ///   - tlsConfiguration: TLS configuration
    ///   - configuration: HTTP2 Upgrade channel configuration
    /// - Returns: HTTPChannelHandler builder
    public static func http2Upgrade(
        tlsConfiguration: TLSConfiguration,
        configuration: HTTP2UpgradeChannel.Configuration = .init()
    ) throws -> HTTPServerBuilder {
        .init { responder in
            try HTTP2UpgradeChannel(
                tlsConfiguration: tlsConfiguration,
                configuration: configuration,
                responder: responder
            )
        }
    }

    /// Build HTTP channel with HTTP2 upgrade
    ///
    /// Use in ``Hummingbird/Application`` initialization.
    /// ```
    /// let app = Application(
    ///     router: router,
    ///     server: .http2Upgrade(configuration: .init(tlsConfiguration: tlsConfiguration))
    /// )
    /// ```
    /// - Parameters:
    ///   - tlsChannelConfiguration: TLS channel configuration
    ///   - configuration: HTTP2 Upgrade channel configuration
    /// - Returns: HTTPChannelHandler builder
    public static func http2Upgrade(
        tlsChannelConfiguration: TLSChannelConfiguration,
        configuration: HTTP2UpgradeChannel.Configuration = .init()
    ) throws -> HTTPServerBuilder {
        .init { responder in
            try HTTP2UpgradeChannel(
                tlsChannelConfiguration: tlsChannelConfiguration,
                configuration: configuration,
                responder: responder
            )
        }
    }

    /// Build plaintext HTTP2 channel
    ///
    /// As this is running on a connection without TLS it cannot perform the upgrade negotiation via ALPN.
    /// Therefore a client will need to know in advance it is connecting to an HTTP2 server. You can
    /// test this with curl as follows: `curl --http2-prior-knowledge http://localhost:8080/`
    ///
    /// Use in ``Hummingbird/Application`` initialization.
    /// ```
    /// let app = Application(
    ///     router: router,
    ///     server: .plaintextHTTP2()
    /// )
    /// ```
    /// - Parameters:
    ///   - configuration: HTTP2 channel configuration
    /// - Returns: HTTPChannelHandler builder
    public static func plaintextHTTP2(
        configuration: HTTP2Channel.Configuration = .init()
    ) -> HTTPServerBuilder {
        .init { responder in
            HTTP2Channel(
                responder: responder,
                configuration: configuration
            )
        }
    }
}
