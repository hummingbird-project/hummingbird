//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOCore

/// Stores channel handlers used in HTTP server
struct HBHTTPChannelHandlers {
    /// Initialize `HBHTTPChannelHandlers`
    init() {
        self.handlers = []
    }

    /// Add autoclosure that creates a ChannelHandler
    public mutating func addHandler(_ handler: @autoclosure @escaping () -> RemovableChannelHandler) {
        self.handlers.append(handler)
    }

    /// Return array of ChannelHandlers
    public func getHandlers() -> [RemovableChannelHandler] {
        return self.handlers.map { $0() }
    }

    private var handlers: [() -> RemovableChannelHandler]
}
