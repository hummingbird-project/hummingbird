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

/// HTTPServer child channel setup protocol
public protocol HBChildChannel: Sendable {
    associatedtype Value: Sendable

    /// Setup child channel
    /// - Parameters:
    ///   - channel: Child channel
    ///   - configuration: Server configuration
    ///   - logger: Logger used during setup
    /// - Returns: Object to process input/output on child channel
    func setup(channel: Channel, logger: Logger) -> EventLoopFuture<Value>

    /// handle messages being passed down the channel pipeline
    /// - Parameters:
    ///   - value: Object to process input/output on child channel
    ///   - logger: Logger to use while processing messages
    func handle(value: Value, logger: Logger) async
}
