//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import HummingbirdCore
import Logging
import NIOCore
import NIOSSL

/// Sets up child channel to use TLS before accessing base channel setup
public struct TLSChannel<BaseChannel: ServerChildChannel>: ServerChildChannel {
    public typealias Value = BaseChannel.Value

    ///  Initialize TLSChannel
    /// - Parameters:
    ///   - baseChannel: Base child channel wrap
    ///   - tlsConfiguration: TLS configuration
    public init(_ baseChannel: BaseChannel, tlsConfiguration: TLSConfiguration) throws {
        self.configuration = try .init(configuration: .init(tlsConfiguration: tlsConfiguration))
        self.baseChannel = baseChannel
    }

    ///  Initialize TLSChannel
    /// - Parameters:
    ///   - baseChannel: Base child channel wrap
    ///   - tlsConfiguration: TLS configuration
    public init(_ baseChannel: BaseChannel, configuration: TLSChannelConfiguration) throws {
        self.configuration = try .init(configuration: configuration)
        self.baseChannel = baseChannel
    }

    /// Setup child channel with TLS and the base channel setup
    /// - Parameters:
    ///   - channel: Child channel
    ///   - logger: Logger used during setup
    /// - Returns: Object to process input/output on child channel
    @inlinable
    public func setup(channel: Channel, logger: Logger) -> EventLoopFuture<Value> {
        channel.eventLoop.makeCompletedFuture {
            try channel.pipeline.syncOperations.addHandler(
                NIOSSLServerHandler(
                    context: self.configuration.sslContext,
                    customVerificationCallback: self.configuration.customVerificationCallback,
                    configuration: .init()
                )
            )
        }.flatMap {
            self.baseChannel.setup(channel: channel, logger: logger)
        }
    }

    /// handle messages being passed down the channel pipeline
    /// - Parameters:
    ///   - value: Object to process input/output on child channel
    ///   - logger: Logger to use while processing messages
    @inlinable
    public func handle(value: BaseChannel.Value, logger: Logging.Logger) async {
        await self.baseChannel.handle(value: value, logger: logger)
    }

    @usableFromInline
    let configuration: TLSChannelInternalConfiguration
    @usableFromInline
    var baseChannel: BaseChannel
}

extension TLSChannel: HTTPChannelHandler where BaseChannel: HTTPChannelHandler {
    public var responder: HTTPChannelHandler.Responder {
        self.baseChannel.responder
    }
}

extension ServerChildChannel {
    /// Construct existential ``TLSChannel`` from existential `ServerChildChannel`
    func withTLS(tlsConfiguration: TLSConfiguration) throws -> any ServerChildChannel {
        try TLSChannel(self, tlsConfiguration: tlsConfiguration)
    }

    /// Construct existential ``TLSChannel`` from existential `ServerChildChannel`
    func withTLS(configuration: TLSChannelConfiguration) throws -> any ServerChildChannel {
        try TLSChannel(self, configuration: configuration)
    }
}

/// TLSChannel configuration
public struct TLSChannelConfiguration: Sendable {
    public typealias CustomVerificationCallback = @Sendable ([NIOSSLCertificate], EventLoopPromise<NIOSSLVerificationResult>) -> Void
    // Manages configuration of TLS
    public let tlsConfiguration: TLSConfiguration
    /// A custom verification callback that allows completely overriding the certificate verification logic of BoringSSL.
    public let customVerificationCallback: CustomVerificationCallback?

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
