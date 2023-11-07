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

import Atomics
import HummingbirdCore
import Logging
import NIOCore
import NIOHTTP1

/*extension HBApplication {
    struct HTTPResponder: HBHTTPResponder {
        let responder: Responder
        let applicationContext: HBApplicationContext
        let dateCache: HBDateCache

        /// Return EventLoopFuture that will be fulfilled with the HTTP response for the supplied HTTP request
        /// - Parameters:
        ///   - request: request
        ///   - context: context from ChannelHandler
        /// - Returns: response
        func respond(to request: HBHTTPRequest, channel: Channel) async throws -> HBHTTPResponse {
            let request = HBRequest(
                head: request.head,
                body: request.body
            )
            let context = Responder.Context(
                applicationContext: self.applicationContext,
                channel: channel,
                logger: loggerWithRequestId(self.applicationContext.logger)
            )
            let httpVersion = request.version

            // respond to request
            var response = try await self.responder.respond(to: request, context: context)
            response.headers.add(name: "Date", value: self.dateCache.date)
            let responseHead = HTTPResponseHead(version: httpVersion, status: response.status, headers: response.headers)
            return HBHTTPResponse(head: responseHead, body: response.body)
        }
    }

    public static func loggerWithRequestId(_ logger: Logger) -> Logger {
        let requestId = globalRequestID.loadThenWrappingIncrement(by: 1, ordering: .relaxed)
        return logger.with(metadataKey: "hb_id", value: .stringConvertible(requestId))
    }
}*/

