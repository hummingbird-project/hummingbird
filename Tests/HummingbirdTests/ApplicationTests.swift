//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import AsyncHTTPClient
import Atomics
import Foundation
import HTTPTypes
import HummingbirdCore
import HummingbirdHTTP2
import HummingbirdTLS
import HummingbirdTesting
import Logging
import NIOConcurrencyHelpers
import NIOCore
import NIOEmbedded
import NIOHTTP1
import NIOHTTPTypes
import NIOSSL
import ServiceLifecycle
import Testing

@testable import Hummingbird

struct ApplicationTests {
    static func randomBuffer(size: Int) -> ByteBuffer {
        var data = [UInt8](repeating: 0, count: size)
        data = data.map { _ in UInt8.random(in: 0...255) }
        return ByteBufferAllocator().buffer(bytes: data)
    }

    @Test func testGetRoute() async throws {
        let router = Router()
        router.get("/hello") { _, _ -> ByteBuffer in
            ByteBuffer(string: "GET: Hello")
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/hello", method: .get) { response in
                #expect(response.status == .ok)
                #expect(String(buffer: response.body) == "GET: Hello")
            }
        }
    }

    @Test func testHTTPStatusRoute() async throws {
        let router = Router()
        router.get("/accepted") { _, _ -> HTTPResponse.Status in
            .accepted
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/accepted", method: .get) { response in
                #expect(response.status == .accepted)
            }
        }
    }

    @Test func testStandardHeaders() async throws {
        let router = Router()
        router.get("/hello") { _, _ in
            "Hello"
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.live) { client in
            try await client.execute(uri: "/hello", method: .get) { response in
                #expect(response.headers[.contentLength] == "5")
                #expect(response.headers[.date] != nil)
            }
        }
    }

    @Test func testServerHeaders() async throws {
        let router = Router()
        router.get("/hello") { _, _ in
            "Hello"
        }
        let app = Application(
            responder: router.buildResponder(),
            configuration: .init(serverName: "TestServer")
        )
        try await app.test(.live) { client in
            try await client.execute(uri: "/hello", method: .get) { response in
                #expect(response.headers[.server] == "TestServer")
            }
        }
    }

    @Test func testPostRoute() async throws {
        let router = Router()
        router.post("/hello") { _, _ -> String in
            "POST: Hello"
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in

            try await client.execute(uri: "/hello", method: .post) { response in
                #expect(response.status == .ok)
                #expect(String(buffer: response.body) == "POST: Hello")
            }
        }
    }

    @Test func testMultipleMethods() async throws {
        let router = Router()
        router.post("/hello") { _, _ -> String in
            "POST"
        }
        router.get("/hello") { _, _ -> String in
            "GET"
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in

            try await client.execute(uri: "/hello", method: .get) { response in
                #expect(String(buffer: response.body) == "GET")
            }
            try await client.execute(uri: "/hello", method: .post) { response in
                #expect(String(buffer: response.body) == "POST")
            }
        }
    }

    @Test func testMultipleGroupMethods() async throws {
        let router = Router()
        router.group("hello")
            .post { _, _ -> String in
                "POST"
            }
            .get { _, _ -> String in
                "GET"
            }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in

            try await client.execute(uri: "/hello", method: .get) { response in
                #expect(String(buffer: response.body) == "GET")
            }
            try await client.execute(uri: "/hello", method: .post) { response in
                #expect(String(buffer: response.body) == "POST")
            }
        }
    }

    @Test func testQueryRoute() async throws {
        let router = Router()
        router.post("/query") { request, _ -> ByteBuffer in
            ByteBuffer(
                string: request.uri.queryParameters["test"].map { String($0) } ?? ""
            )
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in

            try await client.execute(uri: "/query?test=test%20data%C3%A9", method: .post) {
                response in
                #expect(response.status == .ok)
                #expect(String(buffer: response.body) == "test dataé")
            }
        }
    }

    @Test func testMultipleQueriesRoute() async throws {
        let router = Router()
        router.post("/add") { request, _ -> String in
            request.uri.queryParameters.getAll("value", as: Int.self).reduce(0, +)
                .description
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in

            try await client.execute(uri: "/add?value=3&value=45&value=7", method: .post) {
                response in
                #expect(response.status == .ok)
                #expect(String(buffer: response.body) == "55")
            }
        }
    }

    @Test func testArray() async throws {
        let router = Router()
        router.get("array") { _, _ -> [String] in
            ["yes", "no"]
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in

            try await client.execute(uri: "/array", method: .get) { response in
                #expect(String(buffer: response.body) == "[\"yes\",\"no\"]")
            }
        }
    }

    @Test func testErrorOutput() async throws {
        /// Error message returned by Hummingbird
        struct ErrorMessage: Codable {
            struct Details: Codable {
                let message: String
            }

            let error: Details
        }
        let router = Router()
        router.get("error") { _, _ -> HTTPResponse.Status in
            throw HTTPError(.badRequest, message: "BAD!")
        }
        let app = Application(router: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "/error", method: .get) { response in
                let error = try JSONDecoder().decodeByteBuffer(ErrorMessage.self, from: response.body)
                #expect(error.error.message == "BAD!")
            }
        }
    }

    @Test func testErrorHeaders() async throws {
        let router = Router()
        router.get("error") { _, _ -> HTTPResponse.Status in
            throw HTTPError(.badRequest, message: "BAD!")
        }
        let app = Application(router: router, configuration: .init(serverName: "HB"))
        try await app.test(.live) { client in
            try await client.execute(uri: "/error", method: .get) { response in
                #expect(response.headers[.server] == "HB")
                #expect(response.headers[.date] != nil)
            }
        }
    }

    @Test func testResponseBody() async throws {
        let router = Router()
        router
            .group("/echo-body")
            .post { request, _ -> Response in
                let buffer = try await request.body.collect(upTo: .max)
                return .init(status: .ok, headers: [:], body: .init(byteBuffer: buffer))
            }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in

            let buffer = Self.randomBuffer(size: 1_140_000)
            try await client.execute(uri: "/echo-body", method: .post, body: buffer) { response in
                #expect(response.status == .ok)
                #expect(response.body == buffer)
            }
        }
    }

    @Test func testResponseBodySequence() async throws {
        let router = Router()
        router
            .group("/echo-body")
            .post { request, _ -> Response in
                var buffers: [ByteBuffer] = []
                for try await buffer in request.body {
                    buffers.append(buffer)
                }
                return .init(status: .ok, headers: [:], body: .init(contentsOf: buffers))
            }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in

            let buffer = Self.randomBuffer(size: 400_000)
            try await client.execute(uri: "/echo-body", method: .post, body: buffer) { response in
                #expect(response.status == .ok)
                #expect(response.headers[.contentLength] == "400000")
                #expect(response.body == buffer)
            }
        }
    }

    /// Test streaming of requests and streaming of responses by streaming the request body into a response streamer
    @Test func testStreaming() async throws {
        let router = Router()
        router.post("streaming") { request, _ -> Response in
            Response(status: .ok, body: .init(asyncSequence: request.body))
        }
        router.post("size") { request, _ -> String in
            var size = 0
            for try await buffer in request.body {
                size += buffer.readableBytes
            }
            return size.description
        }
        let app = Application(responder: router.buildResponder())

        try await app.test(.router) { client in

            let buffer = Self.randomBuffer(size: 640_001)
            try await client.execute(uri: "/streaming", method: .post, body: buffer) { response in
                #expect(response.status == .ok)
                #expect(response.body == buffer)
            }
            try await client.execute(uri: "/streaming", method: .post) { response in
                #expect(response.status == .ok)
                #expect(response.body == ByteBuffer())
            }
            try await client.execute(uri: "/size", method: .post, body: buffer) { response in
                #expect(String(buffer: response.body) == "640001")
            }
        }
    }

    /// Test streaming of requests and streaming of responses by streaming the request body into a response streamer
    @Test func testStreamingSmallBuffer() async throws {
        let router = Router()
        router.post("streaming") { request, _ -> Response in
            Response(status: .ok, body: .init(asyncSequence: request.body))
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            let buffer = Self.randomBuffer(size: 64)
            try await client.execute(uri: "/streaming", method: .post, body: buffer) { response in
                #expect(response.status == .ok)
                #expect(response.body == buffer)
            }
            try await client.execute(uri: "/streaming", method: .post) { response in
                #expect(response.status == .ok)
                #expect(response.body == ByteBuffer())
            }
        }
    }

    @Test func testCollectBody() async throws {
        struct CollateMiddleware<Context: RequestContext>: RouterMiddleware {
            public func handle(
                _ request: Request,
                context: Context,
                next: (Request, Context) async throws -> Response
            ) async throws -> Response {
                var request = request
                _ = try await request.collectBody(upTo: context.maxUploadSize)
                return try await next(request, context)
            }
        }
        let router = Router()
        router.middlewares.add(CollateMiddleware())
        router.put("/hello") { request, _ -> String in
            let buffer = try await request.body.collect(upTo: .max)
            return buffer.readableBytes.description
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in

            let buffer = Self.randomBuffer(size: 512_000)
            try await client.execute(uri: "/hello", method: .put, body: buffer) { response in
                #expect(String(buffer: response.body) == "512000")
                #expect(response.status == .ok)
            }
        }
    }

    @Test func testDoubleStreaming() async throws {
        let router = Router()
        router.post("size") { request, context -> String in
            var request = request
            _ = try await request.collectBody(upTo: context.maxUploadSize)
            var size = 0
            for try await buffer in request.body {
                size += buffer.readableBytes
            }
            return size.description
        }
        let app = Application(responder: router.buildResponder())

        try await app.test(.router) { client in
            let buffer = Self.randomBuffer(size: 100_000)
            try await client.execute(uri: "/size", method: .post, body: buffer) { response in
                #expect(String(buffer: response.body) == "100000")
            }
        }
    }

    @Test func testOptional() async throws {
        let router = Router()
        router
            .group("/echo-body")
            .post { request, _ -> ByteBuffer? in
                let buffer = try await request.body.collect(upTo: .max)
                return buffer.readableBytes > 0 ? buffer : nil
            }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in

            let buffer = Self.randomBuffer(size: 64)
            try await client.execute(uri: "/echo-body", method: .post, body: buffer) { response in
                #expect(response.status == .ok)
                #expect(response.body == buffer)
            }
            try await client.execute(uri: "/echo-body", method: .post) { response in
                #expect(response.status == .noContent)
            }
        }
    }

    @Test func testOptionalCodable() async throws {
        struct SortedJSONRequestContext: RequestContext {
            var coreContext: CoreRequestContextStorage
            var responseEncoder: JSONEncoder {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .sortedKeys
                return encoder
            }

            init(source: Source) {
                self.coreContext = .init(source: source)
            }
        }
        struct Name: ResponseCodable {
            let first: String
            let last: String
        }
        let router = Router(context: SortedJSONRequestContext.self)
        router
            .group("/name")
            .patch { _, _ -> Name? in
                Name(first: "john", last: "smith")
            }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in

            try await client.execute(uri: "/name", method: .patch) { response in
                #expect(String(buffer: response.body) == #"{"first":"john","last":"smith"}"#)
            }
        }
    }

    @Test func testTypedResponse() async throws {
        let router = Router()
        router.delete("/hello") { _, _ in
            EditedResponse(
                status: .preconditionRequired,
                headers: [.test: "value", .contentType: "application/json"],
                response: "Hello"
            )
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in

            try await client.execute(uri: "/hello", method: .delete) { response in
                #expect(response.status == .preconditionRequired)
                #expect(response.headers[.test] == "value")
                #expect(response.headers[.contentType] == "application/json")
                #expect(String(buffer: response.body) == "Hello")
            }
        }
    }

    @Test func testCodableTypedResponse() async throws {
        struct Result: ResponseEncodable {
            let value: String
        }
        let router = Router()
        router.patch("/hello") { _, _ in
            EditedResponse(
                status: .multipleChoices,
                headers: [.test: "value", .contentType: "application/json"],
                response: Result(value: "true")
            )
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in

            try await client.execute(uri: "/hello", method: .patch) { response in
                #expect(response.status == .multipleChoices)
                #expect(response.headers[.test] == "value")
                #expect(response.headers[.contentType] == "application/json")
                #expect(String(buffer: response.body) == #"{"value":"true"}"#)
            }
        }
    }

    @Test func testMaxUploadSize() async throws {
        struct MaxUploadRequestContext: RequestContext {
            init(source: Source) {
                self.coreContext = .init(source: source)
            }

            var coreContext: CoreRequestContextStorage
            var maxUploadSize: Int { 64 * 1024 }
        }
        let router = Router(context: MaxUploadRequestContext.self)
        router.post("upload") { request, context in
            _ = try await request.body.collect(upTo: context.maxUploadSize)
            return "ok"
        }
        router.post("stream") { _, _ in
            "ok"
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.live) { client in
            let buffer = Self.randomBuffer(size: 128 * 1024)
            // check non streamed route throws an error
            try await client.execute(uri: "/upload", method: .post, body: buffer) { response in
                #expect(response.status == .contentTooLarge)
            }
            // check streamed route doesn't
            try await client.execute(uri: "/stream", method: .post, body: buffer) { response in
                #expect(response.status == .ok)
            }
        }
    }

    @Test func testChunkedTransferEncoding() async throws {
        let router = Router()
            .get("chunked") { _, _ in
                Response(
                    status: .ok,
                    body: .init { writer in
                        try await writer.write(ByteBuffer(string: "Testing"))
                        try await writer.finish(nil)
                    }
                )
            }
        let app = Application(responder: router.buildResponder())
        try await app.test(.live) { client in
            // check streamed route doesn't
            try await client.execute(uri: "/chunked", method: .get) { response in
                #expect(response.headers[.transferEncoding] == "chunked")
            }
        }
    }

    @Test func testRemoteAddress() async throws {
        /// Implementation of a basic request context that supports everything the Hummingbird library needs
        struct SocketAddressRequestContext: RequestContext {
            /// core context
            var coreContext: CoreRequestContextStorage
            // socket address
            let remoteAddress: SocketAddress?

            init(source: Source) {
                self.coreContext = .init(source: source)
                self.remoteAddress = source.channel.remoteAddress
            }
        }
        let router = Router(context: SocketAddressRequestContext.self)
        router.get("/") { _, context -> String in
            switch context.remoteAddress {
            case .v4(let address):
                return String(describing: address.host)
            case .v6(let address):
                return String(describing: address.host)
            default:
                throw HTTPError(.internalServerError)
            }
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.live) { client in

            try await client.execute(uri: "/", method: .get) { response in
                #expect(response.status == .ok)
                let address = String(buffer: response.body)
                #expect(address == "127.0.0.1" || address == "::1")
            }
        }
    }

    /// test we can create an application and pass it around as a `some ApplicationProtocol`. This
    /// is more a compilation test than a runtime test
    @Test func testApplicationProtocolReturnValue() async throws {
        func createApplication() -> some ApplicationProtocol {
            let router = Router()
            router.get("/hello") { _, _ -> ByteBuffer in
                ByteBuffer(string: "GET: Hello")
            }
            return Application(responder: router.buildResponder())
        }
        let app = createApplication()
        try await app.test(.live) { client in
            try await client.execute(uri: "/hello", method: .get) { response in
                #expect(response.status == .ok)
                #expect(String(buffer: response.body) == "GET: Hello")
            }
        }
    }

    /// test we can create out own application type conforming to ApplicationProtocol
    @Test func testApplicationProtocol() async throws {
        struct MyApp: ApplicationProtocol {
            typealias Context = BasicRequestContext

            var responder: some HTTPResponder<Context> {
                let router = Router(context: Context.self)
                router.get("/hello") { _, _ -> ByteBuffer in
                    ByteBuffer(string: "GET: Hello")
                }
                return router.buildResponder()
            }
        }
        let app = MyApp()
        try await app.test(.live) { client in
            try await client.execute(uri: "/hello", method: .get) { response in
                #expect(response.status == .ok)
                #expect(String(buffer: response.body) == "GET: Hello")
            }
        }
    }

    /// test we can create an application that accepts a responder with an empty context
    @Test func testEmptyRequestContext() async throws {
        struct EmptyRequestContext: InitializableFromSource {
            typealias Source = ApplicationRequestContextSource
            init(source: Source) {}
        }
        let app = Application(
            responder: CallbackResponder { (_: Request, _: EmptyRequestContext) in
                Response(status: .ok)
            }
        )
        try await app.test(.live) { client in
            try await client.execute(uri: "/hello", method: .get) { response in
                #expect(response.status == .ok)
            }
        }
    }

    @Test func testHummingbirdServices() async throws {
        struct MyService: Service {
            static let started = ManagedAtomic(false)
            static let shutdown = ManagedAtomic(false)
            func run() async throws {
                Self.started.store(true, ordering: .relaxed)
                try? await gracefulShutdown()
                Self.shutdown.store(true, ordering: .relaxed)
            }
        }
        let router = Router()
        var app = Application(responder: router.buildResponder())
        app.addServices(MyService())
        try await app.test(.live) { _ in
            #expect(MyService.started.load(ordering: .relaxed) == true)
            #expect(MyService.shutdown.load(ordering: .relaxed) == false)
            // shutting down immediately outputs an error
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(MyService.shutdown.load(ordering: .relaxed) == true)
    }

    @Test func testOnServerRunning() async throws {
        let runOnServerRunning = ManagedAtomic(false)
        let router = Router()
        let app = Application(
            responder: router.buildResponder(),
            onServerRunning: { _ in
                runOnServerRunning.store(true, ordering: .relaxed)
            }
        )
        try await app.test(.live) { _ in
            // shutting down immediately outputs an error
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(runOnServerRunning.load(ordering: .relaxed) == true)
    }

    @Test func testRunBeforeServer() async throws {
        let runBeforeServer = ManagedAtomic(false)
        let router = Router()
        var app = Application(
            responder: router.buildResponder(),
            onServerRunning: { _ in
                #expect(runBeforeServer.load(ordering: .relaxed) == true)
            }
        )
        app.beforeServerStarts {
            runBeforeServer.store(true, ordering: .relaxed)
        }
        try await app.test(.live) { _ in
            // shutting down immediately outputs an error
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    /// test we can create out own application type conforming to ApplicationProtocol
    @Test func testTLS() async throws {
        let router = Router()
        router.get("/") { _, _ -> String in
            "Hello"
        }
        let app = try Application(
            responder: router.buildResponder(),
            server: .tls(tlsConfiguration: self.getServerTLSConfiguration())
        )
        try await app.test(.ahc(.https)) { client in
            try await client.execute(uri: "/", method: .get) { response in
                #expect(response.status == .ok)
                let string = String(buffer: response.body)
                #expect(string == "Hello")
            }
        }
    }

    /// test we can create out own application type conforming to ApplicationProtocol
    @Test func testHTTP2() async throws {
        let router = Router()
        router.get("/") { _, _ -> String in
            "Hello"
        }
        let app = try Application(
            responder: router.buildResponder(),
            server: .http2Upgrade(tlsConfiguration: self.getServerTLSConfiguration())
        )
        try await app.test(.ahc(.https)) { client in
            try await client.execute(uri: "/", method: .get) { response in
                #expect(response.status == .ok)
                let string = String(buffer: response.body)
                #expect(string == "Hello")
            }
        }
    }

    /// test we can create out own application type conforming to ApplicationProtocol
    @Test func testApplicationRouterInit() async throws {
        let router = Router()
        router.get("/") { _, _ -> String in
            "Hello"
        }
        let app = Application(router: router)
        try await app.test(.live) { client in
            try await client.execute(uri: "/", method: .get) { response in
                #expect(response.status == .ok)
                let string = String(buffer: response.body)
                #expect(string == "Hello")
            }
        }
    }

    /// test we can create out own application type conforming to ApplicationProtocol
    @Test func testBidirectionalStreaming() async throws {
        let buffer = Self.randomBuffer(size: 1024 * 1024)
        let router = Router()
        router.post("/") { request, _ -> Response in
            .init(
                status: .ok,
                body: .init { writer in
                    for try await buffer in request.body {
                        let processed = ByteBuffer(
                            bytes: buffer.readableBytesView.map { $0 ^ 0xFF }
                        )
                        try await writer.write(processed)
                    }
                    try await writer.finish(nil)
                }
            )
        }
        let app = Application(router: router)
        try await app.test(.live) { client in
            try await client.execute(uri: "/", method: .post, body: buffer) { response in
                #expect(
                    response.body == ByteBuffer(bytes: buffer.readableBytesView.map { $0 ^ 0xFF })
                )
            }
        }
    }

    // MARK: Helper functions

    func getServerTLSConfiguration() throws -> TLSConfiguration {
        let caCertificate = try NIOSSLCertificate(
            bytes: [UInt8](caCertificateData.utf8),
            format: .pem
        )
        let certificate = try NIOSSLCertificate(
            bytes: [UInt8](serverCertificateData.utf8),
            format: .pem
        )
        let privateKey = try NIOSSLPrivateKey(
            bytes: [UInt8](serverPrivateKeyData.utf8),
            format: .pem
        )
        var tlsConfig = TLSConfiguration.makeServerConfiguration(
            certificateChain: [.certificate(certificate)],
            privateKey: .privateKey(privateKey)
        )
        tlsConfig.trustRoots = .certificates([caCertificate])
        return tlsConfig
    }

    @Test func testHTTPError() async throws {
        struct HTTPErrorFormat: Decodable {
            struct ErrorFormat: Decodable {
                let message: String
            }

            let error: ErrorFormat
        }

        final class CollatedResponseWriter: ResponseBodyWriter {
            let collated: NIOLockedValueBox<ByteBuffer>

            init() {
                self.collated = .init(.init())
            }

            func write(_ buffer: ByteBuffer) async throws {
                _ = self.collated.withLockedValue { collated in
                    collated.writeImmutableBuffer(buffer)
                }
            }

            func finish(_: HTTPFields?) async throws {}
        }

        let messages = [
            "basic-message",
            "String\"with\"escaping",
            "String\non\nnewlines",
        ]

        let request = Request(
            head: .init(method: .get, scheme: nil, authority: "example.com", path: "/"),
            body: .init(buffer: ByteBuffer())
        )
        let context = BasicRequestContext(
            source: ApplicationRequestContextSource(
                channel: EmbeddedChannel(),
                logger: Logger(label: #function)
            )
        )

        for message in messages {
            let error = HTTPError(.internalServerError, message: message)
            let response = try error.response(from: request, context: context)
            let writer = CollatedResponseWriter()
            _ = try await response.body.write(writer)
            let format = try JSONDecoder().decodeByteBuffer(HTTPErrorFormat.self, from: writer.collated.withLockedValue { $0 })
            #expect(format.error.message == message)
        }
    }

    /// Test AsyncSequence returned by RequestBody.makeStream()
    @Test func testMakeStream() async throws {
        let router = Router()
        router.post("streaming") { request, context -> Response in
            let body = try await withThrowingTaskGroup(of: Void.self) { group in
                let (requestBody, source) = RequestBody.makeStream()
                group.addTask {
                    for try await buffer in request.body {
                        await source.yield(buffer)
                    }
                    source.finish()
                }
                var body = ByteBuffer()
                for try await buffer in requestBody {
                    var buffer = buffer
                    body.writeBuffer(&buffer)
                }
                return body
            }
            return Response(status: .ok, body: .init(byteBuffer: body))
        }
        let app = Application(responder: router.buildResponder())

        try await app.test(.router) { client in

            let buffer = Self.randomBuffer(size: 640_001)
            try await client.execute(uri: "/streaming", method: .post, body: buffer) { response in
                #expect(response.status == .ok)
                #expect(response.body == buffer)
            }
        }
    }

    /// Test AsyncSequence returned by RequestBody.makeStream() and feeding it data from multiple processes
    @Test func testMakeStreamMultipleSources() async throws {
        let router = Router()
        router.get("numbers") { request, context -> Response in
            let body = try await withThrowingTaskGroup(of: Void.self) { group in
                let (requestBody, source) = RequestBody.makeStream()
                group.addTask {
                    // Add three tasks feeding the source
                    await withThrowingTaskGroup(of: Void.self) { group in
                        group.addTask {
                            for value in 0..<100 {
                                await source.yield(ByteBuffer(string: String(describing: value)))
                            }
                        }
                        group.addTask {
                            for value in 0..<100 {
                                await source.yield(ByteBuffer(string: String(describing: value)))
                            }
                        }
                        group.addTask {
                            for value in 0..<100 {
                                await source.yield(ByteBuffer(string: String(describing: value)))
                            }
                        }
                    }
                    source.finish()
                }
                var body = ByteBuffer()
                for try await buffer in requestBody {
                    var buffer = buffer
                    body.writeBuffer(&buffer)
                    try await Task.sleep(for: .milliseconds(1))
                }
                return body
            }
            return Response(status: .ok, body: .init(byteBuffer: body))
        }
        let app = Application(responder: router.buildResponder())

        try await app.test(.router) { client in
            try await client.execute(uri: "/numbers", method: .get) { response in
                #expect(response.status == .ok)
            }
        }
    }

    #if compiler(>=6.0)
    /// Test consumeWithInboundCloseHandler
    @Test func testConsumeWithInboundHandler() async throws {
        let router = Router()
        router.post("streaming") { request, context -> Response in
            Response(
                status: .ok,
                body: .init { writer in
                    try await request.body.consumeWithInboundCloseHandler { body in
                        try await writer.write(body)
                    } onInboundClosed: {
                    }
                    try await writer.finish(nil)
                }
            )
        }
        let app = Application(responder: router.buildResponder())

        try await app.test(.live) { client in
            let buffer = Self.randomBuffer(size: 640_001)
            try await client.execute(uri: "/streaming", method: .post, body: buffer) { response in
                #expect(response.status == .ok)
                #expect(response.body == buffer)
            }
        }
    }

    /// Test consumeWithInboundCloseHandler
    @Test func testConsumeWithCancellationOnInboundClose() async throws {
        let router = Router()
        router.post("streaming") { request, context -> Response in
            Response(
                status: .ok,
                body: .init { writer in
                    try await request.body.consumeWithCancellationOnInboundClose { body in
                        try await writer.write(body)
                    }
                    try await writer.finish(nil)
                }
            )
        }
        let app = Application(responder: router.buildResponder())

        try await app.test(.live) { client in
            let buffer = Self.randomBuffer(size: 640_001)
            try await client.execute(uri: "/streaming", method: .post, body: buffer) { response in
                #expect(response.status == .ok)
                #expect(response.body == buffer)
            }
        }
    }

    /// Test consumeWithInboundHandler after having collected the Request body
    @Test func testConsumeWithInboundHandlerAfterCollect() async throws {
        let router = Router()
        router.post("streaming") { request, context -> Response in
            var request = request
            _ = try await request.collectBody(upTo: .max)
            let request2 = request
            return Response(
                status: .ok,
                body: .init { writer in
                    try await request2.body.consumeWithInboundCloseHandler { body in
                        try await writer.write(body)
                    } onInboundClosed: {
                    }
                    try await writer.finish(nil)
                }
            )
        }
        let app = Application(responder: router.buildResponder())

        try await app.test(.live) { client in
            let buffer = Self.randomBuffer(size: 640_001)
            try await client.execute(uri: "/streaming", method: .post, body: buffer) { response in
                #expect(response.status == .ok)
                #expect(response.body == buffer)
            }
        }
    }

    /// Test consumeWithInboundHandler after having replaced Request.body with a new streamed RequestBody
    @Test func testConsumeWithInboundHandlerAfterReplacingBody() async throws {
        let router = Router()
        router.post("streaming") { request, context -> Response in
            var request = request
            request.body = .init(
                asyncSequence: request.body.map {
                    let view = $0.readableBytesView.map { $0 ^ 255 }
                    return ByteBuffer(bytes: view)
                }
            )
            let request2 = request
            return Response(
                status: .ok,
                body: .init { writer in
                    try await request2.body.consumeWithInboundCloseHandler { body in
                        try await writer.write(body)
                    } onInboundClosed: {
                    }
                    try await writer.finish(nil)
                }
            )
        }
        let app = Application(responder: router.buildResponder())

        try await app.test(.live) { client in
            let buffer = Self.randomBuffer(size: 640_001)
            let xorBuffer = ByteBuffer(bytes: buffer.readableBytesView.map { $0 ^ 255 })
            try await client.execute(uri: "/streaming", method: .post, body: buffer) { response in
                #expect(response.status == .ok)
                #expect(response.body == xorBuffer)
            }
        }
    }
    #endif

    @Test func testErrorInResponseWriterClosesConnection() async throws {
        let router = Router()
        router.post("error") { request, context -> Response in
            Response(
                status: .ok,
                body: .init { writer in
                    throw HTTPError(.badRequest)
                }
            )
        }
        let app = Application(router: router)
        try await app.test(.live) { client in
            _ = await #expect(throws: HTTPParserError.invalidEOFState) {
                _ = try await client.execute(uri: "/error", method: .post)
            }
        }
    }

    @Test func testIfMatchEtagHeaders() async throws {
        let router = Router()
        router.get("ifMatch") { request, context -> Response in
            try await request.ifMatch(eTag: "5678", context: context) {
                Response(status: .ok)
            }
        }
        let app = Application(router: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "/ifMatch", method: .get) { response in
                #expect(response.status == .preconditionFailed)
            }
            try await client.execute(uri: "/ifMatch", method: .get, headers: [.ifMatch: "5678"]) { response in
                #expect(response.status == .ok)
            }
            try await client.execute(uri: "/ifMatch", method: .get, headers: [.ifMatch: "5679"]) { response in
                #expect(response.status == .preconditionFailed)
                #expect(response.headers[.eTag] == "5678")
            }
        }
    }

    @Test func testIfNoneMatchEtagHeaders() async throws {
        let router = Router()
        router.get("ifNoneMatch") { request, context -> Response in
            try await request.ifNoneMatch(eTag: "1234", context: context) {
                "Hello"
            }
        }
        router.post("ifNoneMatch") { request, context -> Response in
            try await request.ifNoneMatch(eTag: "1234", context: context) {
                Response(status: .ok)
            }
        }
        let app = Application(router: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "/ifNoneMatch", method: .get) { response in
                #expect(response.status == .ok)
            }
            try await client.execute(uri: "/ifNoneMatch", method: .get, headers: [.ifNoneMatch: "1234"]) { response in
                #expect(response.status == .notModified)
                #expect(response.headers[.eTag] == "1234")
            }
            try await client.execute(uri: "/ifNoneMatch", method: .get, headers: [.ifNoneMatch: "1235"]) { response in
                #expect(response.status == .ok)
            }
        }
    }

    @Test func testIfUnmodifiedSinceHeaders() async throws {
        let now = Date.now
        let router = Router()
        router.get("ifUnmodifiedSince") { request, context in
            try await request.ifUnmodifiedSince(modificationDate: now, context: context) {
                HTTPResponse.Status.ok
            }
        }
        let app = Application(router: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "ifUnmodifiedSince", method: .get) { response in
                #expect(response.status == .ok)
            }
            try await client.execute(uri: "ifUnmodifiedSince", method: .get, headers: [.ifUnmodifiedSince: (now - 2).httpHeader]) { response in
                #expect(response.status == .preconditionFailed)
                #expect(response.headers[.lastModified] == now.httpHeader)
            }
            try await client.execute(uri: "ifUnmodifiedSince", method: .get, headers: [.ifUnmodifiedSince: (now + 2).httpHeader]) { response in
                #expect(response.status == .ok)
            }
        }
    }

    @Test func testIfModifiedSinceHeaders() async throws {
        let now = Date.now
        let router = Router()
        router.get("ifModifiedSince") { request, context in
            try await request.ifModifiedSince(modificationDate: now, context: context) {
                "Testing"
            }
        }
        router.post("ifModifiedSince") { request, context in
            try await request.ifModifiedSince(modificationDate: now, context: context) {
                "Testing"
            }
        }
        let app = Application(router: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "ifModifiedSince", method: .get) { response in
                #expect(String(buffer: response.body) == "Testing")
                #expect(response.status == .ok)
            }
            try await client.execute(uri: "ifModifiedSince", method: .get, headers: [.ifModifiedSince: (now - 2).httpHeader]) { response in
                #expect(String(buffer: response.body) == "Testing")
                #expect(response.status == .ok)
            }
            try await client.execute(uri: "ifModifiedSince", method: .get, headers: [.ifModifiedSince: (now + 2).httpHeader]) { response in
                #expect(response.status == .notModified)
                #expect(response.headers[.lastModified] == now.httpHeader)
            }
            // If-Modified-Since can only be used with a GET or HEAD
            try await client.execute(uri: "ifModifiedSince", method: .post, headers: [.ifModifiedSince: (now + 2).httpHeader]) { response in
                #expect(String(buffer: response.body) == "Testing")
                #expect(response.status == .ok)
            }
        }
    }

    @Test func testHTTPProtocolParseError() async throws {
        final class CreateErrorHandler: ChannelInboundHandler, RemovableChannelHandler {
            typealias InboundIn = HTTPRequestPart

            func channelRead(context: ChannelHandlerContext, data: NIOAny) {
                if case .body = self.unwrapInboundIn(data) {
                    context.fireErrorCaught(HTTPParserError.invalidInternalState)
                }
                context.fireChannelRead(data)
            }
        }
        let router = Router()
            .post { request, _ in
                let buffer = try await request.body.collect(upTo: .max)
                print(buffer.readableBytes)
                return HTTPResponse.Status.ok
            }
        var httpConfiguration = HTTP1Channel.Configuration(additionalChannelHandlers: [CreateErrorHandler()])
        httpConfiguration.pipliningAssistance = true
        let app = Application(
            router: router,
            server: .http1(configuration: httpConfiguration)
        )
        try await app.test(.live) { client in
            // client should return badRequest and close the connection
            do {
                try await client.execute(uri: "", method: .post, body: ByteBuffer(string: "Hello")) { response in
                    #expect(response.status == .badRequest)
                }
            } catch TestClient.Error.connectionClosing {
                // sometimes connection close occurs before badRequest is received
            }

            await #expect(throws: ChannelError.ioOnClosedChannel) {
                try await client.execute(uri: "", method: .post)
            }
        }
    }

    @Test func testCancelledRequest() async throws {
        let httpClient = HTTPClient()
        let (stream, cont) = AsyncStream.makeStream(of: Int.self)

        let router = Router()
        router.post("/") { request, context in
            let b = try await request.body.collect(upTo: .max)
            return Response(status: .ok, body: .init(byteBuffer: b))
        }
        var httpConfiguration = HTTP1Channel.Configuration()
        httpConfiguration.pipliningAssistance = true
        let app = Application(
            router: router,
            server: .http1(configuration: httpConfiguration),
            onServerRunning: { cont.yield($0.localAddress!.port!) }
        )
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                let serviceGroup = ServiceGroup(
                    configuration: .init(
                        services: [app],
                        gracefulShutdownSignals: [.sigterm, .sigint],
                        logger: Logger(label: "SG")
                    )
                )

                group.addTask {
                    try await serviceGroup.run()
                }

                let port = await stream.first { _ in true }!
                let task = Task {
                    let count = ManagedAtomic(0)
                    let stream = AsyncStream {
                        let value = count.loadThenWrappingIncrement(by: 1, ordering: .relaxed)
                        if value < 16 {
                            try? await Task.sleep(for: .milliseconds(100))
                            return ByteBuffer(repeating: 0, count: 256)
                        } else {
                            return nil
                        }
                    }
                    var request = HTTPClientRequest(url: "http://localhost:\(port)")
                    request.method = .POST
                    request.body = .stream(stream, length: .known(4096))
                    let response = try await httpClient.execute(request, deadline: .now() + .minutes(30))
                    let result = try await response.body.collect(upTo: .max)
                    print("Result size: \(result.readableBytes)")
                }

                try await Task.sleep(for: .seconds(1))
                task.cancel()
                await serviceGroup.triggerGracefulShutdown()
            }
        } catch {
            try await httpClient.shutdown()
            throw error
        }
        try await httpClient.shutdown()
    }
}

/// HTTPField used during tests
extension HTTPField.Name {
    static let test = Self("HBTest")!
}
