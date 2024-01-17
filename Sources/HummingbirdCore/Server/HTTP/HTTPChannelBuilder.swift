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
///
/// Used when building an ``Hummingbird/HBApplication``. It delays the building
/// of the ``HBChildChannel`` until the HTTP responder has been built.
public struct HBHTTPChannelBuilder<ChildChannel: HBChildChannel>: Sendable {
    /// build child channel from HTTP responder
    public let build: @Sendable (@escaping HTTPChannelHandler.Responder) throws -> ChildChannel

    /// Initialize HBHTTPChannelBuilder
    /// - Parameter build: closure building child channel from HTTP responder
    public init(_ build: @escaping @Sendable (@escaping HTTPChannelHandler.Responder) throws -> ChildChannel) {
        self.build = build
    }
}

extension HBHTTPChannelBuilder {
    ///  Build HTTP1 channel
    ///
    /// Use in ``Hummingbird/HBApplication`` initialization.
    /// ```
    /// let app = HBApplication(
    ///     router: router,
    ///     server: .http1()
    /// )
    /// ```
    /// - Parameter additionalChannelHandlers: Additional channel handlers to add to channel pipeline
    /// - Returns: HTTPChannelHandler builder
    public static func http1(
        additionalChannelHandlers: @autoclosure @escaping @Sendable () -> [any RemovableChannelHandler] = []
    ) -> HBHTTPChannelBuilder<HTTP1Channel> {
        return .init { responder in
            return HTTP1Channel(responder: responder, additionalChannelHandlers: additionalChannelHandlers)
        }
    }
}
