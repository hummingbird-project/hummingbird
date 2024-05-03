//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import Hummingbird
import HummingbirdTesting
import XCTest

final class MiddlewareTests: XCTestCase {
    func randomBuffer(size: Int) -> ByteBuffer {
        var data = [UInt8](repeating: 0, count: size)
        data = data.map { _ in UInt8.random(in: 0...255) }
        return ByteBufferAllocator().buffer(bytes: data)
    }

    func testMiddleware() async throws {
        struct TestMiddleware<Context: BaseRequestContext>: RouterMiddleware {
            public func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
                var response = try await next(request, context)
                response.headers[.test] = "TestMiddleware"
                return response
            }
        }
        let router = Router()
        router.middlewares.add(TestMiddleware())
        router.get("/hello") { _, _ -> String in
            return "Hello"
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/hello", method: .get) { response in
                XCTAssertEqual(response.headers[.test], "TestMiddleware")
            }
        }
    }

    func testMiddlewareOrder() async throws {
        struct TestMiddleware<Context: BaseRequestContext>: RouterMiddleware {
            let string: String
            public func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
                var response = try await next(request, context)
                response.headers[values: .test].append(self.string)
                return response
            }
        }
        let router = Router()
        router.middlewares.add(TestMiddleware(string: "first"))
        router.middlewares.add(TestMiddleware(string: "second"))
        router.get("/hello") { _, _ -> String in
            return "Hello"
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/hello", method: .get) { response in
                // headers come back in opposite order as middleware is applied to responses in that order
                XCTAssertEqual(response.headers[values: .test].first, "second")
                XCTAssertEqual(response.headers[values: .test].last, "first")
            }
        }
    }

    func testMiddlewareRunOnce() async throws {
        struct TestMiddleware<Context: BaseRequestContext>: RouterMiddleware {
            public func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
                var response = try await next(request, context)
                XCTAssertNil(response.headers[.test])
                response.headers[.test] = "alreadyRun"
                return response
            }
        }
        let router = Router()
        router.middlewares.add(TestMiddleware())
        router.get("/hello") { _, _ -> String in
            return "Hello"
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/hello", method: .get) { _ in
            }
        }
    }

    func testMiddlewareRunWhenNoRouteFound() async throws {
        /// Error message returned by Hummingbird
        struct ErrorMessage: Codable {
            struct Details: Codable {
                let message: String
            }

            let error: Details
        }
        struct TestMiddleware<Context: BaseRequestContext>: RouterMiddleware {
            public func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
                do {
                    return try await next(request, context)
                } catch let error as HTTPError where error.status == .notFound {
                    throw HTTPError(.notFound, message: "Edited error")
                }
            }
        }
        let router = Router()
        router.middlewares.add(TestMiddleware())
        let app = Application(responder: router.buildResponder())

        try await app.test(.router) { client in
            try await client.execute(uri: "/hello", method: .get) { response in
                XCTAssertEqual(response.status, .notFound)
                let error = try JSONDecoder().decode(ErrorMessage.self, from: response.body)
                XCTAssertEqual(error.error.message, "Edited error")
            }
        }
    }

    func testEndpointPathInGroup() async throws {
        struct TestMiddleware<Context: BaseRequestContext>: RouterMiddleware {
            public func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
                XCTAssertNotNil(context.endpointPath)
                return try await next(request, context)
            }
        }
        let router = Router()
        router.group()
            .add(middleware: TestMiddleware())
            .get("test") { _, _ in
                return "test"
            }
        let app = Application(responder: router.buildResponder())

        try await app.test(.router) { client in
            try await client.execute(uri: "/test", method: .get) { _ in }
        }
    }

    func testMiddlewareResponseBodyWriter() async throws {
        struct TransformWriter: ResponseBodyWriter {
            let parentWriter: any ResponseBodyWriter
            let allocator: ByteBufferAllocator

            func write(_ buffer: ByteBuffer) async throws {
                let output = self.allocator.buffer(bytes: buffer.readableBytesView.map { $0 ^ 255 })
                try await self.parentWriter.write(output)
            }
        }
        struct TransformMiddleware<Context: BaseRequestContext>: RouterMiddleware {
            public func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
                let response = try await next(request, context)
                var editedResponse = response
                editedResponse.body = .withTrailingHeaders { writer in
                    let transformWriter = TransformWriter(parentWriter: writer, allocator: context.allocator)
                    let tailHeaders = try await response.body.write(transformWriter)
                    return tailHeaders
                }
                return editedResponse
            }
        }
        let router = Router()
        router.group()
            .add(middleware: TransformMiddleware())
            .get("test") { request, _ in
                return Response(status: .ok, body: .init(asyncSequence: request.body))
            }
        let app = Application(responder: router.buildResponder())

        try await app.test(.router) { client in
            let buffer = self.randomBuffer(size: 64000)
            try await client.execute(uri: "/test", method: .get, body: buffer) { response in
                let expectedOutput = ByteBuffer(bytes: buffer.readableBytesView.map { $0 ^ 255 })
                XCTAssertEqual(expectedOutput, response.body)
            }
        }
    }

    func testCORSUseOrigin() async throws {
        let router = Router()
        router.middlewares.add(CORSMiddleware())
        router.get("/hello") { _, _ -> String in
            return "Hello"
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/hello", method: .get, headers: [.origin: "foo.com"]) { response in
                // headers come back in opposite order as middleware is applied to responses in that order
                XCTAssertEqual(response.headers[.accessControlAllowOrigin], "foo.com")
            }
        }
    }

    func testCORSUseAll() async throws {
        let router = Router()
        router.middlewares.add(CORSMiddleware(allowOrigin: .all))
        router.get("/hello") { _, _ -> String in
            return "Hello"
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/hello", method: .get, headers: [.origin: "foo.com"]) { response in
                // headers come back in opposite order as middleware is applied to responses in that order
                XCTAssertEqual(response.headers[.accessControlAllowOrigin], "*")
            }
        }
    }

    func testCORSOptions() async throws {
        let router = Router()
        router.middlewares.add(CORSMiddleware(
            allowOrigin: .all,
            allowHeaders: [.contentType, .authorization],
            allowMethods: [.get, .put, .delete, .options],
            allowCredentials: true,
            exposedHeaders: ["content-length"],
            maxAge: .seconds(3600)
        ))
        router.get("/hello") { _, _ -> String in
            return "Hello"
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/hello", method: .options, headers: [.origin: "foo.com"]) { response in
                // headers come back in opposite order as middleware is applied to responses in that order
                XCTAssertEqual(response.headers[.accessControlAllowOrigin], "*")
                let headers = response.headers[.accessControlAllowHeaders] // .joined(separator: ", ")
                XCTAssertEqual(headers, "content-type, authorization")
                let methods = response.headers[.accessControlAllowMethods] // .joined(separator: ", ")
                XCTAssertEqual(methods, "GET, PUT, DELETE, OPTIONS")
                XCTAssertEqual(response.headers[.accessControlAllowCredentials], "true")
                XCTAssertEqual(response.headers[.accessControlMaxAge], "3600")
                let exposedHeaders = response.headers[.accessControlExposeHeaders] // .joined(separator: ", ")
                XCTAssertEqual(exposedHeaders, "content-length")
            }
        }
    }

    func testRouteLoggingMiddleware() async throws {
        let router = Router()
        router.middlewares.add(LogRequestsMiddleware(.debug))
        router.put("/hello") { _, _ -> String in
            throw HTTPError(.badRequest)
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/hello", method: .put) { _ in
            }
        }
    }
}
