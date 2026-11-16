//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

#if ConfigurationSupport

public import Configuration
import NIOCore

@available(hummingbird 3.0, *)
extension HTTP1Channel.Configuration {
    /// Initialize a HTTP1Channel.Configuration from a ConfigReader
    ///
    /// - Configuration keys
    ///   - `idleTimeout` (double, optional): Time in seconds a connection can be left idle before closing
    ///
    /// - Parameters
    ///   - reader: ConfigReader
    public init(reader: ConfigReader) {
        var configuration = Self()
        if let idleTimeout = reader.double(forKey: "idleTimeout") {
            configuration.idleTimeout = .nanoseconds(Int64(idleTimeout * 1_000_000_000))
        }
        self = configuration
    }
}

#endif
