//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import NIOCore
import NIOSSL

/// TLSChannel configuration
public struct TLSChannelConfiguration: Sendable {
    public typealias CustomVerificationCallback = @Sendable ([NIOSSLCertificate], EventLoopPromise<NIOSSLVerificationResult>) -> Void

    // Manages configuration of TLS
    public var tlsConfiguration: TLSConfiguration
    /// A custom verification callback that allows completely overriding the certificate verification logic of BoringSSL.
    public var customVerificationCallback: CustomVerificationCallback?

    ///  Initialize TLSChannel.Configuration
    ///
    /// For details on custom callback see swift-nio-ssl documentation
    /// https://swiftpackageindex.com/apple/swift-nio-ssl/main/documentation/niossl/niosslcustomverificationcallback
    /// - Parameters:
    ///   - tlsConfiguration: TLS configuration
    ///   - customVerificationCallback: A custom verification callback that allows completely overriding the
    ///         certificate verification logic of BoringSSL.
    public init(
        tlsConfiguration: TLSConfiguration,
        customVerificationCallback: CustomVerificationCallback? = nil
    ) {
        self.tlsConfiguration = tlsConfiguration
        self.customVerificationCallback = customVerificationCallback
    }

    ///  Initialize TLSChannel.Configuration
    ///
    /// For details on custom callback see swift-nio-ssl documentation
    /// https://swiftpackageindex.com/apple/swift-nio-ssl/main/documentation/niossl/niosslcustomverificationcallback
    /// - Parameters:
    ///   - tlsConfiguration: TLS configuration
    ///   - customAsyncVerificationCallback: A custom verification callback that allows completely overriding the
    ///         certificate verification logic of BoringSSL.
    public init(
        tlsConfiguration: TLSConfiguration,
        customAsyncVerificationCallback: @escaping @Sendable ([NIOSSLCertificate]) async throws -> NIOSSLVerificationResult
    ) {
        self.tlsConfiguration = tlsConfiguration
        self.customVerificationCallback = { certificates, promise in
            promise.completeWithTask {
                try await customAsyncVerificationCallback(certificates)
            }
        }
    }
}

/// TLSChannel configuration
@usableFromInline
package struct TLSChannelInternalConfiguration: Sendable {
    // Manages configuration of TLS
    @usableFromInline
    let sslContext: NIOSSLContext
    /// A custom verification callback that allows completely overriding the certificate verification logic of BoringSSL.
    @usableFromInline
    let customVerificationCallback: TLSChannelConfiguration.CustomVerificationCallback?

    init(configuration: TLSChannelConfiguration) throws {
        self.sslContext = try NIOSSLContext(configuration: configuration.tlsConfiguration)
        self.customVerificationCallback = configuration.customVerificationCallback
    }
}
