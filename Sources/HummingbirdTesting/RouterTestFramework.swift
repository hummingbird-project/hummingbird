//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import Atomics
import HTTPTypes
@_spi(Internal) import Hummingbird
@_spi(Internal) import HummingbirdCore
import Logging
import NIOConcurrencyHelpers
import NIOCore
import NIOEmbedded
import NIOHTTPTypes
import NIOPosix
import ServiceLifecycle
import UnixSignals

/// Test sending requests directly to router. This does not setup a live server
@available(macOS 14, iOS 17, tvOS 17, *)
struct RouterTestFramework<Responder: HTTPResponder>: ApplicationTestFramework where Responder.Context: InitializableFromSource {
    let responder: Responder
    let makeContext: @Sendable (Logger) -> Responder.Context
    let services: [any Service]
    let logger: Logger
    let processesRunBeforeServerStart: [@Sendable () async throws -> Void]

    init<App: ApplicationProtocol>(app: App) async throws where App.Responder == Responder, Responder.Context: InitializableFromSource {
        self.responder = try await app.responder
        self.processesRunBeforeServerStart = app.processesRunBeforeServerStart
        self.services = app.services
        self.logger = app.logger
        self.makeContext = { logger in
            Responder.Context(
                source: .init(
                    channel: NIOAsyncTestingChannel(),
                    logger: logger
                )
            )
        }
    }

    /// Run test
    func run<Value>(_ test: @Sendable (Client) async throws -> Value) async throws -> Value {
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
            try await withThrowingTaskGroup(of: TestResponse.self) { group in
                var headers = headers
                if let contentLength = body.map(\.readableBytes) {
                    headers[.contentLength] = String(describing: contentLength)
                }
                let (stream, source) = NIOAsyncChannelInboundStream<HTTPRequestPart>.makeTestingStream()
                let iterator = stream.makeAsyncIterator()
                let requestBody = NIOAsyncChannelRequestBody(iterator: iterator)

                //let (stream, source) = RequestBody.makeStream()
                let request = Request(
                    head: .init(method: method, scheme: "http", authority: "localhost", path: uri, headerFields: headers),
                    body: RequestBody(nioAsyncChannelInbound: requestBody)
                )
                let logger = self.logger.with(metadataKey: "hb.request.id", value: .stringConvertible(RequestID()))
                let context = self.makeContext(logger)

                group.addTask {
                    let response: Response
                    do {
                        response = try await self.responder.respond(to: request, context: context)
                    } catch {
                        response = Response(status: .internalServerError)
                    }
                    let responseWriter = RouterResponseWriter()
                    try await response.body.write(responseWriter)
                    return responseWriter.values.withLockedValue { values in
                        TestResponse(head: response.head, body: values.body, trailerHeaders: values.trailingHeaders)
                    }
                }

                if var body {
                    while body.readableBytes > 0 {
                        let chunkSize = min(32 * 1024, body.readableBytes)
                        let buffer = body.readSlice(length: chunkSize)!
                        source.yield(.body(buffer))
                    }
                }
                source.yield(.end(nil))
                defer {
                    source.finish()
                }
                return try await group.next()!
            }
        }

        var port: Int? { nil }
    }

    struct RouterResponseWriter: ResponseBodyWriter {
        let values: NIOLockedValueBox<(body: ByteBuffer, trailingHeaders: HTTPFields?)>

        init() {
            self.values = .init((body: .init(), trailingHeaders: nil))
        }

        func write(_ buffer: ByteBuffer) async throws {
            _ = self.values.withLockedValue { values in
                values.body.writeImmutableBuffer(buffer)
            }
        }

        func finish(_ headers: HTTPTypes.HTTPFields?) async throws {
            self.values.withLockedValue { values in
                values.trailingHeaders = headers
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
