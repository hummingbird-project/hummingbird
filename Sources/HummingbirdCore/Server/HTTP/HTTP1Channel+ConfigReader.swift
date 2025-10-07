//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2025the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if ExperimentalConfiguration

public import Configuration
import NIOCore

@available(macOS 15, iOS 18, macCatalyst 18, tvOS 18, visionOS 2, *)
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
