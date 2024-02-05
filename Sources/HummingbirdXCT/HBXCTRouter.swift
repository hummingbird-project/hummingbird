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
import NIOHTTPTypes
import NIOPosix
import ServiceLifecycle

/// Test sending requests directly to router. This does not setup a live server
struct HBXCTRouter<Responder: HBResponder>: HBXCTApplication where Responder.Context: HBBaseRequestContext {
    let responder: Responder
    let makeContext: @Sendable (Logger) -> Responder.Context
    let services: [any Service]
    let logger: Logger
    let processesRunBeforeServerStart: [@Sendable () async throws -> Void]

    init<App: HBApplicationProtocol>(app: App) async throws where App.Responder == Responder, Responder.Context: HBRequestContext {
        self.responder = try await app.responder
        self.processesRunBeforeServerStart = app.processesRunBeforeServerStart
        self.services = app.services
        self.logger = app.logger
        self.makeContext = { logger in
            Responder.Context(
                allocator: ByteBufferAllocator(),
                logger: logger
            )
        }
    }

    /// Run test
    func run<Value>(_ test: @escaping @Sendable (HBXCTClientProtocol) async throws -> Value) async throws -> Value {
        let client = Client(
            responder: self.responder,
            logger: self.logger,
            makeContext: self.makeContext
        )
        // run the runBeforeServer processes before we start testing
        for process in self.processesRunBeforeServerStart {
            try await process()
        }
        // if we have no services then just run test
        if self.services.count == 0 {
            return try await test(client)
        }
        // if we have services then setup task group with service group running in separate task from test
        return try await withThrowingTaskGroup(of: Void.self) { group in
            let serviceGroup = ServiceGroup(
                configuration: .init(
                    services: self.services,
                    gracefulShutdownSignals: [.sigterm, .sigint],
                    logger: self.logger
                )
            )
            group.addTask {
                try await serviceGroup.run()
            }
            do {
                let value = try await test(client)
                await serviceGroup.triggerGracefulShutdown()
                return value
            } catch {
                await serviceGroup.triggerGracefulShutdown()
                throw error
            }
        }
    }

    /// HBXCTRouter client. Constructs an `HBRequest` sends it to the router and then converts
    /// resulting response back to XCT response type
    struct Client: HBXCTClientProtocol {
        let responder: Responder
        let logger: Logger
        let makeContext: @Sendable (Logger) -> Responder.Context

        func execute(uri: String, method: HTTPRequest.Method, headers: HTTPFields, body: ByteBuffer?) async throws -> HBXCTResponse {
            return try await withThrowingTaskGroup(of: HBXCTResponse.self) { group in
                let (stream, source) = HBRequestBody.makeStream()
                let request = HBRequest(
                    head: .init(method: method, scheme: "http", authority: "localhost", path: uri, headerFields: headers),
                    body: stream
                )
                let logger = self.logger.with(metadataKey: "hb_id", value: .stringConvertible(RequestID()))
                let context = self.makeContext(logger)

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
                    let trailerHeaders = try await response.body.write(responseWriter)
                    return responseWriter.collated.withLockedValue { collated in
                        HBXCTResponse(head: response.head, body: collated, trailerHeaders: trailerHeaders)
                    }
                }

                if var body {
                    while body.readableBytes > 0 {
                        let chunkSize = min(32 * 1024, body.readableBytes)
                        let buffer = body.readSlice(length: chunkSize)!
                        try await source.yield(buffer)
                    }
                }
                source.finish()
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
