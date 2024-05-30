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
        self.sslContext = try NIOSSLContext(configuration: tlsConfiguration)
        self.baseChannel = baseChannel
    }

    /// Setup child channel with TLS and the base channel setup
    /// - Parameters:
    ///   - channel: Child channel
    ///   - logger: Logger used during setup
    /// - Returns: Object to process input/output on child channel
    @inlinable
    public func setup(channel: Channel, logger: Logger) -> EventLoopFuture<Value> {
        return channel.pipeline.addHandler(NIOSSLServerHandler(context: self.sslContext)).flatMap {
            self.baseChannel.setup(channel: channel, logger: logger)
        }
    }

    @inlinable
    /// handle messages being passed down the channel pipeline
    /// - Parameters:
    ///   - value: Object to process input/output on child channel
    ///   - logger: Logger to use while processing messages
    public func handle(value: BaseChannel.Value, logger: Logging.Logger) async {
        await self.baseChannel.handle(value: value, logger: logger)
    }

    @usableFromInline
    let sslContext: NIOSSLContext
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
}
