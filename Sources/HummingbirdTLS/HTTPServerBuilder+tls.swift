//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import HummingbirdCore
import NIOSSL

extension HTTPServerBuilder {
    /// Build server supporting HTTP with TLS
    ///
    /// Use in ``Hummingbird/Application`` initialization.
    /// ```
    /// let app = Application(
    ///     router: router,
    ///     server: .tls(.http1(), tlsConfiguration: tlsConfiguration)
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - base: Base child channel to wrap with TLS
    ///   - tlsConfiguration: TLS configuration
    /// - Returns: HTTPChannelHandler builder
    public static func tls(
        _ base: HTTPServerBuilder = .http1(),
        tlsConfiguration: TLSConfiguration
    ) throws -> HTTPServerBuilder {
        .init { responder in
            try base.buildChildChannel(responder).withTLS(tlsConfiguration: tlsConfiguration)
        }
    }

    /// Build server supporting HTTP with TLS
    ///
    ///  Use in ``Hummingbird/Application`` initialization.
    ///
    ///  This version of the function adds extra configuration including a custom verification callback
    ///  which can be used to override the standard certificate verification.
    ///
    ///  ```
    ///  let app = Application(
    ///    router: router,
    ///    server: .tls(.http1(), configuration: .init(
    ///         tlsConfiguration: tlsConfiguration,
    ///         customAsyncVerificationCallback: { certificates in .certificateVerified }
    ///    ))
    ///  )
    ///  ```
    ///
    /// - Parameters:
    ///   - base: Base child channel to wrap with TLS
    ///   - configuration: TLS channel configuration
    /// - Returns: HTTPChannelHandler builder
    public static func tls(
        _ base: HTTPServerBuilder = .http1(),
        configuration: TLSChannelConfiguration
    ) throws -> HTTPServerBuilder {
        .init { responder in
            try base.buildChildChannel(responder).withTLS(configuration: configuration)
        }
    }
}
