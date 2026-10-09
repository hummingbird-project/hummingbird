//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import HTTPTypes
import Hummingbird
import HummingbirdCore
import Logging
import NIOCore
import NIOEmbedded
import NIOHTTP1
import NIOHTTPTypesHTTP1
import ServiceLifecycle
import Synchronization
import UnixSignals

/// Test sending requests directly to router. This does not setup a live server
@available(hummingbird 2.0, *)
struct AsyncTestingFramework<Responder: HTTPResponder>: ApplicationTestFramework where Responder.Context: InitializableFromSource {
    final class Client: TestClientProtocol {
        let asyncTestingChannel: NIOAsyncTestingChannel
        let clientTestingChannel: NIOAsyncTestingChannel

        init(_ asyncTestingChannel: NIOAsyncTestingChannel) async throws {
            self.asyncTestingChannel = asyncTestingChannel
            let clientTestingChannel = NIOAsyncTestingChannel()
            self.clientTestingChannel = clientTestingChannel
            try await clientTestingChannel.eventLoop.flatSubmit {
                clientTestingChannel.eventLoop.assumeIsolated().makeCompletedFuture {
                    try clientTestingChannel.pipeline.syncOperations.addHandler(
                        ByteToMessageHandler(HTTPDecoder<HTTPClientResponsePart, HTTPClientRequestPart>())
                    )
                }
            }.get()
        }

        func executeRequest(
            uri: String,
            method: HTTPTypes.HTTPRequest.Method,
            headers: HTTPTypes.HTTPFields,
            body: NIOCore.ByteBuffer?
        ) async throws -> TestResponse {

            var headers = headers
            if let body {
                headers[.contentLength] = String(describing: body.readableBytes)
            }
            var request = ByteBuffer()
            // write head
            request.writeString("\(method) \(uri.first == "/" ? "" : "/")\(uri) HTTP/1.1\r\n")
            // write headers
            for header in headers {
                request.writeString("\(header.name): \(header.value)\r\n")
            }
            request.writeStaticString("\r\n")
            if var body {
                request.writeBuffer(&body)
            }

            let responseBuffer = try await executeRequest(request)

            try await self.clientTestingChannel.writeInbound(responseBuffer)
            var body = ByteBuffer()
            var responseHead: HTTPResponseHead?
            while true {
                let responsePart = try await self.clientTestingChannel.readInbound(as: HTTPClientResponsePart.self)
                switch (responseHead, responsePart) {
                case (nil, .head(let headPart)):
                    responseHead = headPart
                case (.some, .body(var buffer)):
                    body.writeBuffer(&buffer)
                case (.some(let head), .end(let trailers)):
                    let head = try HTTPResponse(head)
                    return TestResponse(head: head, body: body, trailerHeaders: trailers.map { HTTPFields($0, splitCookie: false) })
                case (_, .none):
                    let responseBuffer = try await self.asyncTestingChannel.waitForOutboundWrite(as: ByteBuffer.self)
                    try await self.clientTestingChannel.writeInbound(responseBuffer)
                default:
                    fatalError()
                }
            }
        }

        func executeRequest(_ request: ByteBuffer) async throws -> ByteBuffer {
            try await asyncTestingChannel.writeInbound(request)
            try await self.clientTestingChannel.writeOutbound(
                HTTPClientRequestPart.head(.init(version: .http1_1, method: .GET, uri: "/", headers: .init()))
            )
            return try await self.asyncTestingChannel.waitForOutboundWrite(as: ByteBuffer.self)
        }

        var port: Int? { nil }
    }

    let childChannel: any ServerChildChannel
    let services: [any Service]
    let logger: Logger
    let processesRunBeforeServerStart: [@Sendable () async throws -> Void]

    init<App: ApplicationProtocol>(app: App) async throws where App.Responder == Responder, Responder.Context: InitializableFromSource {
        let dateCache = DateCache()
        self.childChannel = try await app.server.buildChildChannel(app.applicationResponder(app.responder, dateCache: dateCache))
        self.processesRunBeforeServerStart = app.processesRunBeforeServerStart
        self.services = app.services + [dateCache]
        self.logger = app.logger
    }

    func run<Value>(_ test: @Sendable (Client) async throws -> Value) async throws -> Value {
        let channel = NIOAsyncTestingChannel()
        return try await withThrowingTaskGroup(of: Void.self) { group in
            let (stream, cont) = AsyncStream.makeStream(of: Void.self)
            let serviceGroup = ServiceGroup(
                configuration: .init(
                    services: self.services + [FinishContinuationService(cont: cont)],
                    gracefulShutdownSignals: [.sigterm, .sigint],
                    logger: self.logger
                )
            )
            group.addTask {
                try await serviceGroup.run()
            }

            for process in self.processesRunBeforeServerStart {
                try await process()
            }
            do {
                await stream.first { _ in true }
                let value = try await self.childChannel._runTest(channel: channel, logger: self.logger, test: test)
                await serviceGroup.triggerGracefulShutdown()
                return value
            } catch {
                await serviceGroup.triggerGracefulShutdown()
                throw error
            }
        }
    }
}

@available(hummingbird 2.0, *)
extension ServerChildChannel {
    fileprivate func _runTest<Responder: HTTPResponder, Return>(
        channel: any Channel,
        logger: Logger,
        test: @Sendable (AsyncTestingFramework<Responder>.Client) async throws -> Return
    ) async throws -> Return {
        let asyncTestingChannel = NIOAsyncTestingChannel()
        let client = try await AsyncTestingFramework<Responder>.Client(asyncTestingChannel)
        let value = try await asyncTestingChannel.eventLoop.flatSubmit {
            self.setup(channel: asyncTestingChannel, logger: logger)
        }.get()
        return try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.handle(value: value, logger: logger)
            }
            let rt = try await test(client)
            group.cancelAll()
            return rt
        }
    }
}
