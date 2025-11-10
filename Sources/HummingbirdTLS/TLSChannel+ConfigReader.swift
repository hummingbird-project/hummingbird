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

@available(macOS 15, iOS 18, macCatalyst 18, tvOS 18, visionOS 2, *)
extension TLSChannelConfiguration {
    public struct TLSConfigError: Error {
        private enum Internal {
            case missingCertificateChain
            case missingPrivateKey
        }
        private let value: Internal

        public static var missingCertificateChain: Self { .init(value: .missingCertificateChain) }
        public static var missingPrivateKey: Self { .init(value: .missingPrivateKey) }
    }

    /// Initialize a TLSChannelConfiguration from a ConfigReader
    ///
    /// - Configuration Keys
    ///   - `tls.certificateChain` (string, required): TLS certificate chain in PEM format
    ///   - `tls.privateKey` (string required): TLS private key in PEM format
    ///   - `tls.trustRoots` (string optional): TLS trust roots in PEM format
    ///
    /// - Parameter reader: ConfigReader
    /// - Throws: TLSConfigError if "tls.certificate.chain" or "tls.private.key" values are missing
    public init(reader: ConfigReader) throws {
        guard let certificateChainPEM = reader.string(forKey: "tls.certificateChain") else {
            throw TLSConfigError.missingCertificateChain
        }
        guard let privateKeyPEM = reader.string(forKey: "tls.privateKey") else {
            throw TLSConfigError.missingPrivateKey
        }
        let trustRootsPEM = reader.string(forKey: "tls.trustRoots")

        let certificateChain = try NIOSSLCertificate.fromPEMBytes([UInt8](certificateChainPEM.utf8))
        let privateKey = try NIOSSLPrivateKey(bytes: [UInt8](privateKeyPEM.utf8), format: .pem)
        let trustRoots = try trustRootsPEM.map { try NIOSSLCertificate.fromPEMBytes([UInt8]($0.utf8)) }
        var tlsConfiguration = TLSConfiguration.makeServerConfiguration(
            certificateChain: certificateChain.map { .certificate($0) },
            privateKey: .privateKey(privateKey)
        )
        tlsConfiguration.trustRoots = trustRoots.map { .certificates($0) }
        self = .init(tlsConfiguration: tlsConfiguration)
    }
}

#endif
