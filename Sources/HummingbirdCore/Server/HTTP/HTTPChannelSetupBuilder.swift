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

import NIOCore

/// Build Channel Setup that takes an HTTP responder
public struct HBHTTPChannelSetupBuilder<ChannelSetup: HBChannelSetup>: Sendable {
    public let build: @Sendable (@escaping HTTPChannelHandler.Responder) throws -> ChannelSetup
    public init(_ build: @escaping @Sendable (@escaping HTTPChannelHandler.Responder) throws -> ChannelSetup) {
        self.build = build
    }
}

extension HBHTTPChannelSetupBuilder {
    public static func http1(
        additionalChannelHandlers: @autoclosure @escaping @Sendable () -> [any RemovableChannelHandler] = []
    ) -> HBHTTPChannelSetupBuilder<HTTP1Channel> {
        return .init { responder in
            return HTTP1Channel(responder: responder, additionalChannelHandlers: additionalChannelHandlers)
        }
    }
}
