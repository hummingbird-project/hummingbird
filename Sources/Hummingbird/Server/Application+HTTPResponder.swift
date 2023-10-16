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

extension HBApplication {
    struct Responder: HBHTTPResponder {
        let responder: any HBResponder<RequestContext>
        let applicationContext: HBApplicationContext
        let dateCache: HBDateCache

        /// Return EventLoopFuture that will be fulfilled with the HTTP response for the supplied HTTP request
        /// - Parameters:
        ///   - request: request
        ///   - context: context from ChannelHandler
        /// - Returns: response
        public func respond(to request: HBHTTPRequest, context: ChannelHandlerContext, onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void) {
            let request = HBRequest(
                head: request.head,
                body: request.body
            )
            let context = RequestContext.create(
                applicationContext: self.applicationContext,
                channel: context.channel
            )
            let httpVersion = request.version
            // respond to request
            self.responder.respond(to: request, context: context).whenComplete { result in
                switch result {
                case .success(let response):
                    var response = response
                    response.headers.add(name: "Date", value: self.dateCache.date)
                    let responseHead = HTTPResponseHead(version: httpVersion, status: response.status, headers: response.headers)
                    onComplete(.success(HBHTTPResponse(head: responseHead, body: response.body)))

                case .failure(let error):
                    return onComplete(.failure(error))
                }
            }
        }
    }

    /// Context object for Channel to be provided to HBRequest
    struct ChannelRequestContext: HBChannelContextProtocol {
        let channel: Channel
        var eventLoop: EventLoop { return self.channel.eventLoop }
        var allocator: ByteBufferAllocator { return self.channel.allocator }
        var remoteAddress: SocketAddress? { return self.channel.remoteAddress }
    }
}
