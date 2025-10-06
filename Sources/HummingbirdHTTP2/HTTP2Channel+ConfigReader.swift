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

#if ExperimentalConfiguration

public import Configuration
import HummingbirdCore

@available(macOS 15, iOS 18, macCatalyst 18, tvOS 18, visionOS 2, *)
extension HTTP2Channel.Configuration {
    /// Initialize a HTTP2Channel.Configuration from a ConfigReader
    ///
    /// - Configuration Keys
    ///   - `h2.idle.timeout` (double optional): Time in seconds before an HTTP2 connection should be closed.
    ///   - `h2.graceful.close.timeout` (double optional): Time in seconds to wait for client response after
    ///     all streams have been closed.
    ///   - `h2.max.age.timeout` (double optional): Maximum time in seconds a connection can stay open.
    ///   - `h2.stream`: HTTP2 stream options. See ``HTTP1Channel/Configuration/init(reader:)``
    ///
    /// - Parameters
    ///   - reader: ConfigReader
    public init(reader: ConfigReader) {
        var configuration = Self()
        if let idleTimeout = reader.double(forKey: "h2.idle.timeout") {
            configuration.idleTimeout = .seconds(idleTimeout)
        }
        if let gracefulCloseTimeout = reader.double(forKey: "h2.graceful.close.timeout") {
            configuration.gracefulCloseTimeout = .seconds(gracefulCloseTimeout)
        }
        if let maxAgeTimeout = reader.double(forKey: "h2.max.age.timeout") {
            configuration.maxAgeTimeout = .seconds(maxAgeTimeout)
        }
        let streamReader = reader.scoped(to: "h2.stream")
        configuration.streamConfiguration = HTTP1Channel.Configuration(reader: streamReader)
        self = configuration
    }
}

#endif
