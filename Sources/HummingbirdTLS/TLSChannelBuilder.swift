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
import NIOSSL

extension HBHTTPChannelBuilder {
    ///  Build child channel supporting HTTP with TLS
    ///
    /// Use in ``Hummingbird/HBApplication`` initialization.
    /// ```
    /// let app = HBApplication(
    ///     router: router,
    ///     server: .tls(.http1(), tlsConfiguration: tlsConfiguration)
    /// )
    /// ```
    /// - Parameters:
    ///   - base: Base child channel to wrap with TLS
    ///   - tlsConfiguration: TLS configuration
    /// - Returns: HTTPChannelHandler builder
    public static func tls<BaseChannel: HBServerChildChannel>(
        _ base: HBHTTPChannelBuilder<BaseChannel> = .http1(),
        tlsConfiguration: TLSConfiguration
    ) throws -> HBHTTPChannelBuilder<TLSChannel<BaseChannel>> {
        return .init { responder in
            return try TLSChannel(base.build(responder), tlsConfiguration: tlsConfiguration)
        }
    }
}
