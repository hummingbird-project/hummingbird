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
import HTTPTypes
@_spi(HBXCT) import Hummingbird
@_spi(HBXCT) import HummingbirdCore
import Logging
import NIOConcurrencyHelpers
import NIOCore
import NIOPosix
import Tracing

public protocol HBTestRequestContextProtocol: HBBaseRequestContext {
    init(
        applicationContext: HBApplicationContext,
        eventLoop: EventLoop,
        allocator: ByteBufferAllocator,
        logger: Logger
    )
}

public struct HBTestRouterContext: HBTestRequestContextProtocol, HBRequestContext {
    public init(
        applicationContext: HBApplicationContext,
        eventLoop: EventLoop,
        allocator: ByteBufferAllocator,
        logger: Logger
    ) {
        self.coreContext = .init(
            applicationContext: applicationContext,
            eventLoop: eventLoop,
            allocator: allocator,
            logger: logger
        )
    }

    public init(
        applicationContext: HBApplicationContext,
        channel: Channel,
        logger: Logger
    ) {
        self.coreContext = .init(
            applicationContext: applicationContext,
            eventLoop: channel.eventLoop,
            allocator: channel.allocator,
            logger: logger
        )
    }

    /// router context
    public var coreContext: HBCoreRequestContext
}

/// Test sending values to requests to router. This does not setup a live server
struct HBXCTRouter<Responder: HBResponder>: HBXCTApplication where Responder.Context: HBTestRequestContextProtocol {
    let eventLoopGroup: EventLoopGroup
    let context: HBApplicationContext
    let responder: Responder

    init(app: HBApplication<Responder, HTTP1Channel>) {
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
        let responder: Responder
        let applicationContext: HBApplicationContext

        func execute(uri: String, method: HTTPRequest.Method, headers: HTTPFields, body: ByteBuffer?) async throws -> HBXCTResponse {
            let eventLoop = self.eventLoopGroup.any()

            return try await withThrowingTaskGroup(of: HBXCTResponse.self) { group in
                let streamer = HBStreamedRequestBody()
                let request = HBRequest(
                    head: .init(method: method, scheme: nil, authority: nil, path: uri, headerFields: headers),
                    body: .stream(streamer)
                )
                let context = Responder.Context(
                    applicationContext: self.applicationContext,
                    eventLoop: eventLoop,
                    allocator: ByteBufferAllocator(),
                    logger: HBApplication<Responder, HTTP1Channel>.loggerWithRequestId(self.applicationContext.logger)
                )

                group.addTask {
                    let response: HBResponse
                    do {
                        response = try await self.responder.respond(to: request, context: context)
                    } catch let error as HBHTTPResponseError {
                        let httpResponse = error.response(allocator: ByteBufferAllocator())
                        response = HBResponse(status: httpResponse.status, headers: httpResponse.headers, body: httpResponse.body)
                    } catch {
                        response = HBResponse(status: .internalServerError)
                    }
                    let responseWriter = RouterResponseWriter()
                    try await response.body.write(responseWriter)
                    for try await _ in request.body {}
                    return responseWriter.collated.withLockedValue { collated in
                        HBXCTResponse(head: response.head, body: collated)
                    }
                }

                if var body = body {
                    while body.readableBytes > 0 {
                        let chunkSize = min(32 * 1024, body.readableBytes)
                        let buffer = body.readSlice(length: chunkSize)!
                        await streamer.send(buffer)
                    }
                }
                streamer.finish()
                return try await group.next()!
            }
        }
    }

    final class RouterResponseWriter: HBResponseBodyWriter {
        let collated: NIOLockedValueBox<ByteBuffer>

        init() {
            self.collated = .init(.init())
        }

        func write(_ buffer: ByteBuffer) async throws {
            _ = self.collated.withLockedValue { collated in
                collated.writeImmutableBuffer(buffer)
            }
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
