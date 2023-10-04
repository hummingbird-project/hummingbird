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
        internal static let globalRequestID = ManagedAtomic(0)

        let responder: HBResponder
        let applicationContext: HBApplication.Context
        let dateCache: HBDateCache

        /// Return EventLoopFuture that will be fulfilled with the HTTP response for the supplied HTTP request
        /// - Parameters:
        ///   - request: request
        ///   - context: context from ChannelHandler
        /// - Returns: response
        public func respond(to request: HBHTTPRequest, context: ChannelHandlerContext, onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void) {
            let requestId = String(Self.globalRequestID.loadThenWrappingIncrement(by: 1, ordering: .relaxed))
            let request = HBRequest(
                head: request.head,
                body: request.body
            )
            let context = ChannelRequestContext(
                channel: context.channel, 
                applicationContext: self.applicationContext, 
                requestId: requestId
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
    struct ChannelRequestContext: HBRequestContext {
        let channel: Channel
        let applicationContext: HBApplication.Context
        var eventLoop: EventLoop { return self.channel.eventLoop }
        var allocator: ByteBufferAllocator { return self.channel.allocator }
        var remoteAddress: SocketAddress? { return self.channel.remoteAddress }
        let requestId: String
        private let _endpointPath = HBUnsafeMutableTransferBox<String?>(nil)
        var endpointPath: String? {
            get { _endpointPath.wrappedValue }
            nonmutating set { _endpointPath.wrappedValue = newValue }
        }
    }
}
