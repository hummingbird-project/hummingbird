//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import Logging
import NIOCore
import NIOPosix

final class ServerErrorHandler: ChannelInboundHandler {
    typealias InboundIn = NIOAny
    typealias InboundOut = NIOAny

    let logger: Logger

    init(logger: Logger) {
        self.logger = logger
    }

    func errorCaught(context: ChannelHandlerContext, error: any Error) {
        switch error {
        case is NIOFcntlFailedError:
            // On macOS, this error can be caused by a race condition when a connection is created and closed
            // in quick succession. We don't want to propagate this error as it will shutdown the server.
            logger.debug("Server channel error", metadata: ["error": "\(error)"])
        default:
            logger.error("Server channel error", metadata: ["error": "\(error)"])
            context.fireErrorCaught(error)
        }
    }
}
