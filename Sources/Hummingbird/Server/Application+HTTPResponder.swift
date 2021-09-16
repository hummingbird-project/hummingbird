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

import HummingbirdCore
import Logging
import NIOHTTP1

extension HBApplication {
    // MARK: HTTPResponder

    /// HTTP responder class for Hummingbird. This is the interface between Hummingbird and HummingbirdCore
    ///
    /// The HummingbirdCore server calls `respond` to get the HTTP response from Hummingbird
    public struct HTTPResponder: HBHTTPResponder {
        let application: HBApplication
        let responder: HBResponder

        /// Construct HTTP responder
        /// - Parameter application: application creating this responder
        public init(application: HBApplication) {
            self.application = application
            // application responder has been set for sure
            self.responder = application.constructResponder()
        }

        /// Logger used by responder
        public var logger: Logger { return self.application.logger }

        /// Return EventLoopFuture that will be fulfilled with the HTTP response for the supplied HTTP request
        /// - Parameters:
        ///   - request: request
        ///   - context: context from ChannelHandler
        /// - Returns: response
        public func respond(to request: HBHTTPRequest, context: ChannelHandlerContext, onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void) {
            let request = HBRequest(
                head: request.head,
                body: request.body,
                application: self.application,
                context: ChannelRequestContext(channel: context.channel)
            )

            // respond to request
            self.responder.respond(to: request).whenComplete { result in
                switch result {
                case .success(let response):
                    var response = response
                    response.headers.add(name: "Date", value: HBDateCache.getDateCache(on: context.eventLoop).currentDate)
                    let responseHead = HTTPResponseHead(version: request.version, status: response.status, headers: response.headers)
                    onComplete(.success(HBHTTPResponse(head: responseHead, body: response.body)))

                case .failure(let error):
                    return onComplete(.failure(error))
                }
            }
        }
    }

    /// Context object for Channel to be provided to HBRequest
    struct ChannelRequestContext: HBRequestContext {
        let channel: Channel
        var eventLoop: EventLoop { return self.channel.eventLoop }
        var allocator: ByteBufferAllocator { return self.channel.allocator }
        var remoteAddress: SocketAddress? { return self.channel.remoteAddress }
    }
}
