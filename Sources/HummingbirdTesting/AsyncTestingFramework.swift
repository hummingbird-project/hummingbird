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

/// Test sending requests directly to router. This does not setup a live server
@available(hummingbird 2.0, *)
struct AsyncTestingFramework<Responder: HTTPResponder>: ApplicationTestFramework where Responder.Context: InitializableFromSource {
    final class Client: TestClientProtocol {
        let asyncTestingChannel: NIOAsyncTestingChannel

        init() throws {
            self.asyncTestingChannel = .init()
            try self.asyncTestingChannel.pipeline.syncOperations.addHandler(
                ByteToMessageHandler(HTTPDecoder<HTTPClientResponsePart, ByteBuffer>())
            )
        }

        func executeRequest(
            uri: String,
            method: HTTPTypes.HTTPRequest.Method,
            headers: HTTPTypes.HTTPFields,
            body: NIOCore.ByteBuffer?
        ) async throws -> TestResponse {
            var request = ByteBuffer()
            // write head
            request.writeString("\(method) \(uri) HTTP/1.1\r\n")
            // write headers
            for header in headers {
                request.writeString("\(header.name): \(header.value)\r\n")
            }
            request.writeString("\r\n")
            try await asyncTestingChannel.writeInbound(request)

            var responsePart = try await asyncTestingChannel.waitForOutboundWrite(as: HTTPClientResponsePart.self)
            guard case .head(let headPart) = responsePart else { fatalError() }
            var body = ByteBuffer()
            while true {
                responsePart = try await asyncTestingChannel.waitForOutboundWrite(as: HTTPClientResponsePart.self)
                switch responsePart {
                case .head:
                    fatalError()
                case .body(var buffer):
                    body.writeBuffer(&buffer)
                case .end(let trailers):
                    let head = try HTTPResponse(headPart)
                    return TestResponse(head: head, body: body, trailerHeaders: trailers.map { HTTPFields($0, splitCookie: false) })
                }
            }
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
        self.services = app.services
        self.logger = app.logger
    }

    func run<Value>(_ test: @Sendable (Client) async throws -> Value) async throws -> Value {

    }
}
