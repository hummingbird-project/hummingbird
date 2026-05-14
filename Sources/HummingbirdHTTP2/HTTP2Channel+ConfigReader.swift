//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

#if ConfigurationSupport

public import Configuration
import HummingbirdCore

@available(macOS 15, iOS 18, macCatalyst 18, tvOS 18, visionOS 2, *)
extension HTTP2Channel.Configuration {
    /// Initialize a HTTP2Channel.Configuration from a ConfigReader
    ///
    /// - Configuration Keys
    ///   - `h2.idleTimeout` (double optional): Time in seconds before an HTTP2 connection should be closed.
    ///   - `h2.gracefulCloseTimeout` (double optional): Time in seconds to wait for client response after
    ///     all streams have been closed.
    ///   - `h2.maxAgeTimeout` (double optional): Maximum time in seconds a connection can stay open.
    ///   - `h2.stream`: HTTP2 stream options. See ``HummingbirdCore/HTTP1Channel/Configuration/init(reader:)``
    ///
    /// - Parameters
    ///   - reader: ConfigReader
    public init(reader: ConfigReader) {
        var configuration = Self()
        if let idleTimeout = reader.double(forKey: "http2.idleTimeout") {
            configuration.idleTimeout = .seconds(idleTimeout)
        }
        if let gracefulCloseTimeout = reader.double(forKey: "http2.gracefulCloseTimeout") {
            configuration.gracefulCloseTimeout = .seconds(gracefulCloseTimeout)
        }
        if let maxAgeTimeout = reader.double(forKey: "http2.maxAgeTimeout") {
            configuration.maxAgeTimeout = .seconds(maxAgeTimeout)
        }
        let streamReader = reader.scoped(to: "http2.stream")
        configuration.streamConfiguration = HTTP1Channel.Configuration(reader: streamReader)
        self = configuration
    }
}

#endif
