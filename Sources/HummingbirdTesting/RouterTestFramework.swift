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
import NIOEmbedded
@_spi(Internal) import Hummingbird
@_spi(Internal) import HummingbirdCore
import Logging
import NIOConcurrencyHelpers
import NIOCore
import NIOHTTPTypes
import NIOPosix
import ServiceLifecycle

/// Test sending requests directly to router. This does not setup a live server
struct RouterTestFramework<Responder: HTTPResponder>: ApplicationTestFramework where Responder.Context: BaseRequestContext {
    let responder: Responder
    let makeContext: @Sendable (Logger) -> Responder.Context
    let services: [any Service]
    let logger: Logger
    let processesRunBeforeServerStart: [@Sendable () async throws -> Void]

    init<App: ApplicationProtocol>(app: App) async throws where App.Responder == Responder, Responder.Context: RequestContext {
        self.responder = try await app.responder
        self.processesRunBeforeServerStart = app.processesRunBeforeServerStart
        self.services = app.services
        self.logger = app.logger
        self.makeContext = { logger in
            Responder.Context(
                channel: NIOAsyncTestingChannel(),
                logger: logger
            )
        }
    }

    /// Run test
    func run<Value>(_ test: @escaping @Sendable (TestClientProtocol) async throws -> Value) async throws -> Value {
        let client = Client(
            responder: self.responder,
            logger: self.logger,
            makeContext: self.makeContext
        )
        // if we have no services then just run test
        if self.services.count == 0 {
            // run the runBeforeServer processes before we run test closure.
            for process in self.processesRunBeforeServerStart {
                try await process()
            }
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
                // run the runBeforeServer processes before we run test closure. Need to do this
                // after we have run the serviceGroup though
                for process in self.processesRunBeforeServerStart {
                    try await process()
                }
                let value = try await test(client)
                await serviceGroup.triggerGracefulShutdown()
                return value
            } catch {
                await serviceGroup.triggerGracefulShutdown()
                throw error
            }
        }
    }

    /// RouterTestFramework client. Constructs an `Request` sends it to the router and then converts
    /// resulting response back to test response type
    struct Client: TestClientProtocol {
        let responder: Responder
        let logger: Logger
        let makeContext: @Sendable (Logger) -> Responder.Context

        func executeRequest(uri: String, method: HTTPRequest.Method, headers: HTTPFields, body: ByteBuffer?) async throws -> TestResponse {
            return try await withThrowingTaskGroup(of: TestResponse.self) { group in
                var headers = headers
                if let contentLength = body.map(\.readableBytes) {
                    headers[.contentLength] = String(describing: contentLength)
                }
                let (stream, source) = RequestBody.makeStream()
                let request = Request(
                    head: .init(method: method, scheme: "http", authority: "localhost", path: uri, headerFields: headers),
                    body: stream
                )
                let logger = self.logger.with(metadataKey: "hb_id", value: .stringConvertible(RequestID()))
                let context = self.makeContext(logger)

                group.addTask {
                    let response: Response
                    do {
                        response = try await self.responder.respond(to: request, context: context)
                    } catch let error as HTTPResponseError {
                        let httpResponse = error.response(allocator: ByteBufferAllocator())
                        response = Response(status: httpResponse.status, headers: httpResponse.headers, body: httpResponse.body)
                    } catch {
                        response = Response(status: .internalServerError)
                    }
                    let responseWriter = RouterResponseWriter()
                    let trailerHeaders = try await response.body.write(responseWriter)
                    return responseWriter.collated.withLockedValue { collated in
                        TestResponse(head: response.head, body: collated, trailerHeaders: trailerHeaders)
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

        var port: Int? { nil }
    }

    final class RouterResponseWriter: ResponseBodyWriter {
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
