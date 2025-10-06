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

import Configuration
import HummingbirdHTTP2
import HummingbirdTLS
import Testing

struct ConfigReaderTests {
    @Test
    @available(macOS 15, iOS 18, macCatalyst 18, tvOS 18, visionOS 2, *)
    func testTLSChannelConfigReader() throws {
        let configReader = ConfigReader(
            providers: [
                InMemoryProvider(values: [
                    "tls.certificate.chain": .init(stringLiteral: serverCertificateData),
                    "tls.private.key": .init(stringLiteral: serverPrivateKeyData),
                    "tls.trust.roots": .init(stringLiteral: caCertificateData),
                ])
            ]
        )

        let tlsConfig = try TLSChannelConfiguration(reader: configReader)
        let serverTLSConfiguration = try getServerTLSConfiguration()
        #expect(tlsConfig.tlsConfiguration.certificateChain == serverTLSConfiguration.certificateChain)
        #expect(tlsConfig.tlsConfiguration.privateKey == serverTLSConfiguration.privateKey)
        #expect(tlsConfig.tlsConfiguration.trustRoots == serverTLSConfiguration.trustRoots)
    }

    @Test
    @available(macOS 15, iOS 18, macCatalyst 18, tvOS 18, visionOS 2, *)
    func testHTTP2ChannelConfigReader() throws {
        let configReader = ConfigReader(
            providers: [
                InMemoryProvider(values: [
                    "h2.idle.timeout": 46.0,
                    "h2.max.age.timeout": 500.5,
                    "h2.graceful.close.timeout": 2.25,
                    "h2.stream.idle.timeout": 15.0,
                ])
            ]
        )

        let http2Config = HTTP2Channel.Configuration(reader: configReader)
        #expect(http2Config.idleTimeout == .seconds(46))
        #expect(http2Config.maxAgeTimeout == .seconds(500.5))
        #expect(http2Config.gracefulCloseTimeout == .seconds(2.25))
        #expect(http2Config.streamConfiguration.idleTimeout == .seconds(15))
    }
}

#endif
