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

import Atomics
import Hummingbird
import Logging
import NIOCore
import NIOPosix

/// Test sending values to requests to router. This does not setup a live server
struct HBXCTRouter: HBXCTApplication {
    /// Dummy request context
    struct XCTChannelContext: HBChannelContextProtocol {
        let eventLoop: EventLoop
        var allocator: ByteBufferAllocator { ByteBufferAllocator() }
        var remoteAddress: SocketAddress? { return nil }
    }

    let eventLoopGroup: EventLoopGroup
    let context: HBApplication.Context
    let responder: HBResponder

    init(builder: HBApplicationBuilder) {
        self.eventLoopGroup = builder.eventLoopGroup
        self.context = HBApplication.Context(
            threadPool: builder.threadPool,
            configuration: builder.configuration,
            logger: builder.logger,
            encoder: builder.encoder,
            decoder: builder.decoder
        )
        self.responder = builder.router.buildRouter()
    }

    func shutdown() async throws {
        try await self.context.threadPool.shutdownGracefully()
    }

    /// Run test
    func run<Value>(_ test: @escaping @Sendable (HBXCTClientProtocol) async throws -> Value) async throws -> Value {
        let client = Client(eventLoopGroup: self.eventLoopGroup, responder: self.responder, applicationContext: self.context)
        let value = try await test(client)
        try await self.shutdown()
        return value
    }

    /// HBXCTRouter client. Constructs an `HBRequest` sends it to the router and then converts
    /// resulting response back to XCT response type
    struct Client: HBXCTClientProtocol {
        let eventLoopGroup: EventLoopGroup
        let responder: HBResponder
        let applicationContext: HBApplication.Context

        func execute(uri: String, method: HTTPMethod, headers: HTTPHeaders, body: ByteBuffer?) async throws -> HBXCTResponse {
            let eventLoop = self.eventLoopGroup.any()

            return try await eventLoop.flatSubmit {
                let request = HBRequest(
                    head: .init(version: .http1_1, method: method, uri: uri, headers: headers),
                    body: .byteBuffer(body)
                )
                let context = HBRequestContext(
                    applicationContext: self.applicationContext,
                    channelContext: XCTChannelContext(eventLoop: eventLoop)
                )
                return self.responder.respond(to: request, context: context)
                    .flatMapErrorThrowing { error in
                        switch error {
                        case let error as HBHTTPResponseError:
                            let httpResponse = error.response(version: .http1_1, allocator: ByteBufferAllocator())
                            return HBResponse(status: httpResponse.head.status, headers: httpResponse.head.headers, body: httpResponse.body)
                        default:
                            return HBResponse(status: .internalServerError)
                        }
                    }
                    .flatMap { response in
                        let promise = eventLoop.makePromise(of: HBXCTResponse.self)
                        promise.completeWithTask {
                            let body: ByteBuffer?
                            switch response.body {
                            case .byteBuffer(let buffer):
                                body = buffer
                            case .empty:
                                body = nil
                            case .stream(let streamer):
                                var colllateBuffer = ByteBuffer()
                                streamerReadLoop:
                                    while true {
                                    switch try await streamer.read(on: eventLoop).get() {
                                    case .byteBuffer(var part):
                                        colllateBuffer.writeBuffer(&part)
                                    case .end:
                                        break streamerReadLoop
                                    }
                                }
                                body = colllateBuffer
                            }
                            return HBXCTResponse(status: response.status, headers: response.headers, body: body)
                        }
                        return promise.futureResult
                    }
            }.get()
        }
    }
}
