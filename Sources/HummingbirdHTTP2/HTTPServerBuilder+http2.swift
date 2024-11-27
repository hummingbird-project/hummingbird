//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import HummingbirdCore
import NIOCore
import NIOSSL

extension HTTPServerBuilder {
    ///  Build HTTP channel with HTTP2 upgrade
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

    ///  Build HTTP channel with HTTP2 upgrade
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
}
