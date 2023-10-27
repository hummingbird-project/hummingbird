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
import Tracing

public protocol HBTestRouterContextProtocol: HBTracingRequestContext {
    init(applicationContext: HBApplicationContext, eventLoop: EventLoop, logger: Logger)
}

extension HBTestRouterContextProtocol {
    ///  Initialize an `HBRequestContext`
    /// - Parameters:
    ///   - applicationContext: Context from Application that instigated the request
    ///   - channelContext: Context providing source for EventLoop
    public init(
        applicationContext: HBApplicationContext,
        channel: Channel,
        logger: Logger
    ) {
        self.init(applicationContext: applicationContext, eventLoop: channel.eventLoop, logger: logger)
    }
}

public struct HBTestRouterContext: HBTestRouterContextProtocol, HBRemoteAddressRequestContext {
    public init(applicationContext: HBApplicationContext, eventLoop: EventLoop, logger: Logger) {
        self.coreContext = .init(applicationContext: applicationContext, eventLoop: eventLoop, logger: logger)
        self.serviceContext = .topLevel
    }

    /// router context
    public var coreContext: HBCoreRequestContext
    /// ServiceContext
    public var serviceContext: ServiceContext
    /// Connected remote host
    public var remoteAddress: SocketAddress? { nil }
}

/// Test sending values to requests to router. This does not setup a live server
struct HBXCTRouter<RequestContext: HBTestRouterContextProtocol>: HBXCTApplication {
    let eventLoopGroup: EventLoopGroup
    let context: HBApplicationContext
    let responder: any HBResponder<RequestContext>

    init(app: HBApplication<RequestContext>) {
        self.eventLoopGroup = app.eventLoopGroup
        self.context = HBApplicationContext(
            threadPool: app.threadPool,
            configuration: app.configuration,
            logger: app.logger,
            encoder: app.encoder,
            decoder: app.decoder
        )
        self.responder = app.responder
    }

    /// Run test
    func run<Value>(_ test: @escaping @Sendable (HBXCTClientProtocol) async throws -> Value) async throws -> Value {
        let client = Client(eventLoopGroup: self.eventLoopGroup, responder: self.responder, applicationContext: self.context)
        let value = try await test(client)
        return value
    }

    /// HBXCTRouter client. Constructs an `HBRequest` sends it to the router and then converts
    /// resulting response back to XCT response type
    struct Client: HBXCTClientProtocol {
        let eventLoopGroup: EventLoopGroup
        let responder: any HBResponder<RequestContext>
        let applicationContext: HBApplicationContext

        func execute(uri: String, method: HTTPMethod, headers: HTTPHeaders, body: ByteBuffer?) async throws -> HBXCTResponse {
            let eventLoop = self.eventLoopGroup.any()

            return try await eventLoop.flatSubmit {
                let request = HBRequest(
                    head: .init(version: .http1_1, method: method, uri: uri, headers: headers),
                    body: .byteBuffer(body)
                )
                let context = RequestContext(
                    applicationContext: self.applicationContext,
                    eventLoop: eventLoop,
                    logger: HBApplication<RequestContext>.loggerWithRequestId(self.applicationContext.logger)
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
                                    while true
                                {
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

extension Logger {
    /// Create new Logger with additional metadata value
    /// - Parameters:
    ///   - metadataKey: Metadata key
    ///   - value: Metadata value
    /// - Returns: Logger
    func with(metadataKey: String, value: MetadataValue) -> Logger {
        var logger = self
        logger[metadataKey: metadataKey] = value
        return logger
    }
}

/// Current global request ID
private let globalRequestID = ManagedAtomic(0)
