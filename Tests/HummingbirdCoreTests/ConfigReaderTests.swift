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

#if ConfigurationSupport

import Configuration
import HummingbirdTLS
import Testing

struct ConfigReaderTests {
    @Test
    @available(macOS 15, iOS 18, macCatalyst 18, tvOS 18, visionOS 2, *)
    func testTLSChannelConfigReader() throws {
        let configReader = ConfigReader(
            providers: [
                InMemoryProvider(values: [
                    "tls.certificateChain": .init(stringLiteral: serverCertificateData),
                    "tls.privateKey": .init(stringLiteral: serverPrivateKeyData),
                    "tls.trustRoots": .init(stringLiteral: caCertificateData),
                ])
            ]
        )

        let tlsConfig = try TLSChannelConfiguration(reader: configReader)
        let serverTLSConfiguration = try getServerTLSConfiguration()
        #expect(tlsConfig.tlsConfiguration.certificateChain == serverTLSConfiguration.certificateChain)
        #expect(tlsConfig.tlsConfiguration.privateKey == serverTLSConfiguration.privateKey)
        #expect(tlsConfig.tlsConfiguration.trustRoots == serverTLSConfiguration.trustRoots)
    }
}

#endif
