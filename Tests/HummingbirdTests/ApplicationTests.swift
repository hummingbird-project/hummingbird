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

import Atomics
import HTTPTypes
import Hummingbird
import HummingbirdCore
import HummingbirdHTTP2
import HummingbirdTesting
import HummingbirdTLS
import Logging
import NIOConcurrencyHelpers
import NIOCore
import NIOEmbedded
import NIOSSL
import ServiceLifecycle
import XCTest

final class ApplicationTests: XCTestCase {
    func randomBuffer(size: Int) -> ByteBuffer {
        var data = [UInt8](repeating: 0, count: size)
        data = data.map { _ in UInt8.random(in: 0...255) }
        return ByteBufferAllocator().buffer(bytes: data)
    }

    func testGetRoute() async throws {
        let router = Router()
        router.get("/hello") { _, context -> ByteBuffer in
            return ByteBuffer(string: "GET: Hello")
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/hello", method: .get) { response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(String(buffer: response.body), "GET: Hello")
            }
        }
    }

    func testHTTPStatusRoute() async throws {
        let router = Router()
        router.get("/accepted") { _, _ -> HTTPResponse.Status in
            return .accepted
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/accepted", method: .get) { response in
                XCTAssertEqual(response.status, .accepted)
            }
        }
    }

    func testStandardHeaders() async throws {
        let router = Router()
        router.get("/hello") { _, _ in
            return "Hello"
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.live) { client in
            try await client.execute(uri: "/hello", method: .get) { response in
                XCTAssertEqual(response.headers[.contentLength], "5")
                XCTAssertNotNil(response.headers[.date])
            }
        }
    }

    func testServerHeaders() async throws {
        let router = Router()
        router.get("/hello") { _, _ in
            return "Hello"
        }
        let app = Application(
            responder: router.buildResponder(), configuration: .init(serverName: "TestServer")
        )
        try await app.test(.live) { client in
            try await client.execute(uri: "/hello", method: .get) { response in
                XCTAssertEqual(response.headers[.server], "TestServer")
            }
        }
    }

    func testPostRoute() async throws {
        let router = Router()
        router.post("/hello") { _, _ -> String in
            return "POST: Hello"
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in

            try await client.execute(uri: "/hello", method: .post) { response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(String(buffer: response.body), "POST: Hello")
            }
        }
    }

    func testMultipleMethods() async throws {
        let router = Router()
        router.post("/hello") { _, _ -> String in
            return "POST"
        }
        router.get("/hello") { _, _ -> String in
            return "GET"
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in

            try await client.execute(uri: "/hello", method: .get) { response in
                XCTAssertEqual(String(buffer: response.body), "GET")
            }
            try await client.execute(uri: "/hello", method: .post) { response in
                XCTAssertEqual(String(buffer: response.body), "POST")
            }
        }
    }

    func testMultipleGroupMethods() async throws {
        let router = Router()
        router.group("hello")
            .post { _, _ -> String in
                return "POST"
            }
            .get { _, _ -> String in
                return "GET"
            }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in

            try await client.execute(uri: "/hello", method: .get) { response in
                XCTAssertEqual(String(buffer: response.body), "GET")
            }
            try await client.execute(uri: "/hello", method: .post) { response in
                XCTAssertEqual(String(buffer: response.body), "POST")
            }
        }
    }

    func testQueryRoute() async throws {
        let router = Router()
        router.post("/query") { request, context -> ByteBuffer in
            return ByteBuffer(
                string: request.uri.queryParameters["test"].map { String($0) } ?? "")
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in

            try await client.execute(uri: "/query?test=test%20data%C3%A9", method: .post) {
                response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(String(buffer: response.body), "test dataé")
            }
        }
    }

    func testMultipleQueriesRoute() async throws {
        let router = Router()
        router.post("/add") { request, _ -> String in
            return request.uri.queryParameters.getAll("value", as: Int.self).reduce(0, +)
                .description
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in

            try await client.execute(uri: "/add?value=3&value=45&value=7", method: .post) {
                response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(String(buffer: response.body), "55")
            }
        }
    }

    func testArray() async throws {
        let router = Router()
        router.get("array") { _, _ -> [String] in
            return ["yes", "no"]
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in

            try await client.execute(uri: "/array", method: .get) { response in
                XCTAssertEqual(String(buffer: response.body), "[\"yes\",\"no\"]")
            }
        }
    }

    func testErrorOutput() async throws {
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
                let error = try JSONDecoder().decode(ErrorMessage.self, from: response.body)
                XCTAssertEqual(error.error.message, "BAD!")
            }
        }
    }

    func testErrorHeaders() async throws {
        let router = Router()
        router.get("error") { _, _ -> HTTPResponse.Status in
            throw HTTPError(.badRequest, message: "BAD!")
        }
        let app = Application(router: router, configuration: .init(serverName: "HB"))
        try await app.test(.live) { client in
            try await client.execute(uri: "/error", method: .get) { response in
                XCTAssertEqual(response.headers[.server], "HB")
                XCTAssertNotNil(response.headers[.date])
            }
        }
    }

    func testResponseBody() async throws {
        let router = Router()
        router
            .group("/echo-body")
            .post { request, _ -> Response in
                let buffer = try await request.body.collect(upTo: .max)
                return .init(status: .ok, headers: [:], body: .init(byteBuffer: buffer))
            }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in

            let buffer = self.randomBuffer(size: 1_140_000)
            try await client.execute(uri: "/echo-body", method: .post, body: buffer) { response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(response.body, buffer)
            }
        }
    }

    /// Test streaming of requests and streaming of responses by streaming the request body into a response streamer
    func testStreaming() async throws {
        let router = Router()
        router.post("streaming") { request, _ -> Response in
            return Response(status: .ok, body: .init(asyncSequence: request.body))
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

            let buffer = self.randomBuffer(size: 640_001)
            try await client.execute(uri: "/streaming", method: .post, body: buffer) { response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(response.body, buffer)
            }
            try await client.execute(uri: "/streaming", method: .post) { response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(response.body, ByteBuffer())
            }
            try await client.execute(uri: "/size", method: .post, body: buffer) { response in
                XCTAssertEqual(String(buffer: response.body), "640001")
            }
        }
    }

    /// Test streaming of requests and streaming of responses by streaming the request body into a response streamer
    func testStreamingSmallBuffer() async throws {
        let router = Router()
        router.post("streaming") { request, _ -> Response in
            return Response(status: .ok, body: .init(asyncSequence: request.body))
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            let buffer = self.randomBuffer(size: 64)
            try await client.execute(uri: "/streaming", method: .post, body: buffer) { response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(response.body, buffer)
            }
            try await client.execute(uri: "/streaming", method: .post) { response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(response.body, ByteBuffer())
            }
        }
    }

    func testCollectBody() async throws {
        struct CollateMiddleware<Context: RequestContext>: RouterMiddleware {
            public func handle(
                _ request: Request, context: Context,
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

            let buffer = self.randomBuffer(size: 512_000)
            try await client.execute(uri: "/hello", method: .put, body: buffer) { response in
                XCTAssertEqual(String(buffer: response.body), "512000")
                XCTAssertEqual(response.status, .ok)
            }
        }
    }

    func testDoubleStreaming() async throws {
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
            let buffer = self.randomBuffer(size: 100_000)
            try await client.execute(uri: "/size", method: .post, body: buffer) { response in
                XCTAssertEqual(String(buffer: response.body), "100000")
            }
        }
    }

    func testOptional() async throws {
        let router = Router()
        router
            .group("/echo-body")
            .post { request, _ -> ByteBuffer? in
                let buffer = try await request.body.collect(upTo: .max)
                return buffer.readableBytes > 0 ? buffer : nil
            }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in

            let buffer = self.randomBuffer(size: 64)
            try await client.execute(uri: "/echo-body", method: .post, body: buffer) { response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(response.body, buffer)
            }
            try await client.execute(uri: "/echo-body", method: .post) { response in
                XCTAssertEqual(response.status, .noContent)
            }
        }
    }

    func testOptionalCodable() async throws {
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
                return Name(first: "john", last: "smith")
            }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in

            try await client.execute(uri: "/name", method: .patch) { response in
                XCTAssertEqual(String(buffer: response.body), #"{"first":"john","last":"smith"}"#)
            }
        }
    }

    func testTypedResponse() async throws {
        let router = Router()
        router.delete("/hello") { _, _ in
            return EditedResponse(
                status: .preconditionRequired,
                headers: [.test: "value", .contentType: "application/json"],
                response: "Hello"
            )
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in

            try await client.execute(uri: "/hello", method: .delete) { response in
                XCTAssertEqual(response.status, .preconditionRequired)
                XCTAssertEqual(response.headers[.test], "value")
                XCTAssertEqual(response.headers[.contentType], "application/json")
                XCTAssertEqual(String(buffer: response.body), "Hello")
            }
        }
    }

    func testCodableTypedResponse() async throws {
        struct Result: ResponseEncodable {
            let value: String
        }
        let router = Router()
        router.patch("/hello") { _, _ in
            return EditedResponse(
                status: .multipleChoices,
                headers: [.test: "value", .contentType: "application/json"],
                response: Result(value: "true")
            )
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in

            try await client.execute(uri: "/hello", method: .patch) { response in
                XCTAssertEqual(response.status, .multipleChoices)
                XCTAssertEqual(response.headers[.test], "value")
                XCTAssertEqual(response.headers[.contentType], "application/json")
                XCTAssertEqual(String(buffer: response.body), #"{"value":"true"}"#)
            }
        }
    }

    func testMaxUploadSize() async throws {
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
            let buffer = self.randomBuffer(size: 128 * 1024)
            // check non streamed route throws an error
            try await client.execute(uri: "/upload", method: .post, body: buffer) { response in
                XCTAssertEqual(response.status, .contentTooLarge)
            }
            // check streamed route doesn't
            try await client.execute(uri: "/stream", method: .post, body: buffer) { response in
                XCTAssertEqual(response.status, .ok)
            }
        }
    }

    func testRemoteAddress() async throws {
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
                XCTAssertEqual(response.status, .ok)
                let address = String(buffer: response.body)
                XCTAssert(address == "127.0.0.1" || address == "::1")
            }
        }
    }

    /// test we can create an application and pass it around as a `some ApplicationProtocol`. This
    /// is more a compilation test than a runtime test
    func testApplicationProtocolReturnValue() async throws {
        func createApplication() -> some ApplicationProtocol {
            let router = Router()
            router.get("/hello") { _, context -> ByteBuffer in
                return ByteBuffer(string: "GET: Hello")
            }
            return Application(responder: router.buildResponder())
        }
        let app = createApplication()
        try await app.test(.live) { client in
            try await client.execute(uri: "/hello", method: .get) { response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(String(buffer: response.body), "GET: Hello")
            }
        }
    }

    /// test we can create out own application type conforming to ApplicationProtocol
    func testApplicationProtocol() async throws {
        struct MyApp: ApplicationProtocol {
            typealias Context = BasicRequestContext

            var responder: some HTTPResponder<Context> {
                let router = Router(context: Context.self)
                router.get("/hello") { _, context -> ByteBuffer in
                    return ByteBuffer(string: "GET: Hello")
                }
                return router.buildResponder()
            }
        }
        let app = MyApp()
        try await app.test(.live) { client in
            try await client.execute(uri: "/hello", method: .get) { response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(String(buffer: response.body), "GET: Hello")
            }
        }
    }

    /// test we can create an application that accepts a responder with an empty context
    func testEmptyRequestContext() async throws {
        struct EmptyRequestContext: InitializableFromSource {
            typealias Source = ApplicationRequestContextSource
            init(source: Source) {}
        }
        let app = Application(
            responder: CallbackResponder { (_: Request, _: EmptyRequestContext) in
                return Response(status: .ok)
            }
        )
        try await app.test(.live) { client in
            try await client.execute(uri: "/hello", method: .get) { response in
                XCTAssertEqual(response.status, .ok)
            }
        }
    }

    func testHummingbirdServices() async throws {
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
            XCTAssertEqual(MyService.started.load(ordering: .relaxed), true)
            XCTAssertEqual(MyService.shutdown.load(ordering: .relaxed), false)
            // shutting down immediately outputs an error
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(MyService.shutdown.load(ordering: .relaxed), true)
    }

    func testOnServerRunning() async throws {
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
        XCTAssertEqual(runOnServerRunning.load(ordering: .relaxed), true)
    }

    func testRunBeforeServer() async throws {
        let runBeforeServer = ManagedAtomic(false)
        let router = Router()
        var app = Application(
            responder: router.buildResponder(),
            onServerRunning: { _ in
                XCTAssertEqual(runBeforeServer.load(ordering: .relaxed), true)
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
    func testTLS() async throws {
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
                XCTAssertEqual(response.status, .ok)
                let string = String(buffer: response.body)
                XCTAssertEqual(string, "Hello")
            }
        }
    }

    /// test we can create out own application type conforming to ApplicationProtocol
    func testHTTP2() async throws {
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
                XCTAssertEqual(response.status, .ok)
                let string = String(buffer: response.body)
                XCTAssertEqual(string, "Hello")
            }
        }
    }

    /// test we can create out own application type conforming to ApplicationProtocol
    func testApplicationRouterInit() async throws {
        let router = Router()
        router.get("/") { _, _ -> String in
            "Hello"
        }
        let app = Application(router: router)
        try await app.test(.live) { client in
            try await client.execute(uri: "/", method: .get) { response in
                XCTAssertEqual(response.status, .ok)
                let string = String(buffer: response.body)
                XCTAssertEqual(string, "Hello")
            }
        }
    }

    /// test we can create out own application type conforming to ApplicationProtocol
    func testBidirectionalStreaming() async throws {
        let buffer = self.randomBuffer(size: 1024 * 1024)
        let router = Router()
        router.post("/") { request, context -> Response in
            .init(
                status: .ok,
                body: .init { writer in
                    for try await buffer in request.body {
                        let processed = ByteBuffer(
                            bytes: buffer.readableBytesView.map { $0 ^ 0xFF })
                        try await writer.write(processed)
                    }
                }
            )
        }
        let app = Application(router: router)
        try await app.test(.live) { client in
            try await client.execute(uri: "/", method: .post, body: buffer) { response in
                XCTAssertEqual(
                    response.body, ByteBuffer(bytes: buffer.readableBytesView.map { $0 ^ 0xFF })
                )
            }
        }
    }

    // MARK: Helper functions

    func getServerTLSConfiguration() throws -> TLSConfiguration {
        let caCertificate = try NIOSSLCertificate(
            bytes: [UInt8](caCertificateData.utf8), format: .pem
        )
        let certificate = try NIOSSLCertificate(
            bytes: [UInt8](serverCertificateData.utf8), format: .pem
        )
        let privateKey = try NIOSSLPrivateKey(
            bytes: [UInt8](serverPrivateKeyData.utf8), format: .pem
        )
        var tlsConfig = TLSConfiguration.makeServerConfiguration(
            certificateChain: [.certificate(certificate)], privateKey: .privateKey(privateKey)
        )
        tlsConfig.trustRoots = .certificates([caCertificate])
        return tlsConfig
    }

    func testHTTPError() async throws {
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
            let format = try JSONDecoder().decode(HTTPErrorFormat.self, from: writer.collated.withLockedValue { $0 })
            XCTAssertEqual(format.error.message, message)
        }
    }
}

/// HTTPField used during tests
extension HTTPField.Name {
    static let test = Self("HBTest")!
}
