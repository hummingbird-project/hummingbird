//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Logging
import NIOCore
import NIOHTTP1

public struct HTTP1Channel: HTTPChannelSetup {
    public typealias In = HTTPServerRequestPart
    public typealias Out = SendableHTTPServerResponsePart

    public init(
        additionalChannelHandlers: @autoclosure @escaping @Sendable () -> [any RemovableChannelHandler] = [],
        _ responder: @escaping @Sendable (HBHTTPRequest, Channel) async throws -> HBHTTPResponse
    ) {
        self.additionalChannelHandlers = additionalChannelHandlers
        self.responder = responder
    }

    public func initialize(channel: Channel, configuration: HBServerConfiguration, logger: Logger) -> EventLoopFuture<Void> {
        let childChannelHandlers: [RemovableChannelHandler] = self.additionalChannelHandlers() + [
            HBHTTPUserEventHandler(logger: logger),
            HBHTTPSendableResponseChannelHandler(),
        ]
        return channel.eventLoop.makeCompletedFuture {
            try channel.pipeline.syncOperations.configureHTTPServerPipeline(
                withPipeliningAssistance: configuration.withPipeliningAssistance,
                withErrorHandling: true
            )
            try channel.pipeline.syncOperations.addHandlers(childChannelHandlers)
        }
    }

    public let responder: @Sendable (HBHTTPRequest, Channel) async throws -> HBHTTPResponse
    let additionalChannelHandlers: @Sendable () -> [any RemovableChannelHandler]
}
