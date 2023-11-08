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
import HummingbirdXCT
import XCTest

final class MiddlewareTests: XCTestCase {
    func randomBuffer(size: Int) -> ByteBuffer {
        var data = [UInt8](repeating: 0, count: size)
        data = data.map { _ in UInt8.random(in: 0...255) }
        return ByteBufferAllocator().buffer(bytes: data)
    }

    func testMiddleware() async throws {
        struct TestMiddleware<Context: HBRequestContext>: HBMiddleware {
            func apply(to request: HBRequest, context: Context, next: any HBResponder<Context>) async throws -> HBResponse {
                var response = try await next.respond(to: request, context: context)
                response.headers.replaceOrAdd(name: "middleware", value: "TestMiddleware")
                return response
            }
        }
        let router = HBRouterBuilder(context: HBTestRouterContext.self)
        router.middlewares.add(TestMiddleware())
        router.get("/hello") { _, _ -> String in
            return "Hello"
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/hello", method: .GET) { response in
                XCTAssertEqual(response.headers["middleware"].first, "TestMiddleware")
            }
        }
    }

    func testMiddlewareOrder() async throws {
        struct TestMiddleware<Context: HBRequestContext>: HBMiddleware {
            let string: String
            func apply(to request: HBRequest, context: Context, next: any HBResponder<Context>) async throws -> HBResponse {
                var response = try await next.respond(to: request, context: context)
                response.headers.add(name: "middleware", value: self.string)
                return response
            }
        }
        let router = HBRouterBuilder(context: HBTestRouterContext.self)
        router.middlewares.add(TestMiddleware(string: "first"))
        router.middlewares.add(TestMiddleware(string: "second"))
        router.get("/hello") { _, _ -> String in
            return "Hello"
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/hello", method: .GET) { response in
                // headers come back in opposite order as middleware is applied to responses in that order
                XCTAssertEqual(response.headers["middleware"].first, "second")
                XCTAssertEqual(response.headers["middleware"].last, "first")
            }
        }
    }

    func testMiddlewareRunOnce() async throws {
        struct TestMiddleware<Context: HBRequestContext>: HBMiddleware {
            func apply(to request: HBRequest, context: Context, next: any HBResponder<Context>) async throws -> HBResponse {
                var response = try await next.respond(to: request, context: context)
                XCTAssertNil(response.headers["alreadyRun"].first)
                response.headers.add(name: "alreadyRun", value: "true")
                return response
            }
        }
        let router = HBRouterBuilder(context: HBTestRouterContext.self)
        router.middlewares.add(TestMiddleware())
        router.get("/hello") { _, _ -> String in
            return "Hello"
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/hello", method: .GET) { _ in
            }
        }
    }

    func testMiddlewareRunWhenNoRouteFound() async throws {
        struct TestMiddleware<Context: HBRequestContext>: HBMiddleware {
            func apply(to request: HBRequest, context: Context, next: any HBResponder<Context>) async throws -> HBResponse {
                do {
                    return try await next.respond(to: request, context: context)
                } catch let error as HBHTTPError where error.status == .notFound {
                    throw HBHTTPError(.notFound, message: "Edited error")
                }
            }
        }
        let router = HBRouterBuilder(context: HBTestRouterContext.self)
        router.middlewares.add(TestMiddleware())
        let app = HBApplication(responder: router.buildResponder())

        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/hello", method: .GET) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "Edited error")
                XCTAssertEqual(response.status, .notFound)
            }
        }
    }

    func testEndpointPathInGroup() async throws {
        struct TestMiddleware<Context: HBRequestContext>: HBMiddleware {
            func apply(to request: HBRequest, context: Context, next: any HBResponder<Context>) async throws -> HBResponse {
                XCTAssertNotNil(context.endpointPath)
                return try await next.respond(to: request, context: context)
            }
        }
        let router = HBRouterBuilder(context: HBTestRouterContext.self)
        router.group()
            .add(middleware: TestMiddleware())
            .get("test") { _, _ in
                return "test"
            }
        let app = HBApplication(responder: router.buildResponder())

        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/test", method: .GET) { _ in }
        }
    }

    func testMiddlewareResponseBodyWriter() async throws {
        struct TransformWriter: HBResponseBodyWriter {
            let parentWriter: any HBResponseBodyWriter
            let allocator: ByteBufferAllocator

            func write(_ buffer: ByteBuffer) async throws {
                let output = self.allocator.buffer(bytes: buffer.readableBytesView.map { $0 ^ 255 })
                try await self.parentWriter.write(output)
            }
        }
        struct TransformMiddleware<Context: HBRequestContext>: HBMiddleware {
            func apply(to request: HBRequest, context: Context, next: any HBResponder<Context>) async throws -> HBResponse {
                let response = try await next.respond(to: request, context: context)
                var editedResponse = response
                editedResponse.body = .init { writer in
                    let transformWriter = TransformWriter(parentWriter: writer, allocator: context.allocator)
                    try await response.body.write(transformWriter)
                }
                return editedResponse
            }
        }
        let router = HBRouterBuilder(context: HBTestRouterContext.self)
        router.group()
            .add(middleware: TransformMiddleware())
            .get("test", options: .streamBody) { request, _ in
                return HBResponse(status: .ok, body: .init(asyncSequence: request.body))
            }
        let app = HBApplication(responder: router.buildResponder())

        try await app.test(.router) { client in
            let buffer = self.randomBuffer(size: 64000)
            try await client.XCTExecute(uri: "/test", method: .GET, body: buffer) { response in
                let expectedOutput = ByteBuffer(bytes: buffer.readableBytesView.map { $0 ^ 255 })
                XCTAssertEqual(expectedOutput, response.body)
            }
        }
    }

    func testCORSUseOrigin() async throws {
        let router = HBRouterBuilder(context: HBTestRouterContext.self)
        router.middlewares.add(HBCORSMiddleware())
        router.get("/hello") { _, _ -> String in
            return "Hello"
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/hello", method: .GET, headers: ["origin": "foo.com"]) { response in
                // headers come back in opposite order as middleware is applied to responses in that order
                XCTAssertEqual(response.headers["Access-Control-Allow-Origin"].first, "foo.com")
            }
        }
    }

    func testCORSUseAll() async throws {
        let router = HBRouterBuilder(context: HBTestRouterContext.self)
        router.middlewares.add(HBCORSMiddleware(allowOrigin: .all))
        router.get("/hello") { _, _ -> String in
            return "Hello"
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/hello", method: .GET, headers: ["origin": "foo.com"]) { response in
                // headers come back in opposite order as middleware is applied to responses in that order
                XCTAssertEqual(response.headers["Access-Control-Allow-Origin"].first, "*")
            }
        }
    }

    func testCORSOptions() async throws {
        let router = HBRouterBuilder(context: HBTestRouterContext.self)
        router.middlewares.add(HBCORSMiddleware(
            allowOrigin: .all,
            allowHeaders: ["content-type", "authorization"],
            allowMethods: [.GET, .PUT, .DELETE, .OPTIONS],
            allowCredentials: true,
            exposedHeaders: ["content-length"],
            maxAge: .seconds(3600)
        ))
        router.get("/hello") { _, _ -> String in
            return "Hello"
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/hello", method: .OPTIONS, headers: ["origin": "foo.com"]) { response in
                // headers come back in opposite order as middleware is applied to responses in that order
                XCTAssertEqual(response.headers["Access-Control-Allow-Origin"].first, "*")
                let headers = response.headers[canonicalForm: "Access-Control-Allow-Headers"].joined(separator: ", ")
                XCTAssertEqual(headers, "content-type, authorization")
                let methods = response.headers[canonicalForm: "Access-Control-Allow-Methods"].joined(separator: ", ")
                XCTAssertEqual(methods, "GET, PUT, DELETE, OPTIONS")
                XCTAssertEqual(response.headers["Access-Control-Allow-Credentials"].first, "true")
                XCTAssertEqual(response.headers["Access-Control-Max-Age"].first, "3600")
                let exposedHeaders = response.headers[canonicalForm: "Access-Control-Expose-Headers"].joined(separator: ", ")
                XCTAssertEqual(exposedHeaders, "content-length")
            }
        }
    }

    func testRouteLoggingMiddleware() async throws {
        let router = HBRouterBuilder(context: HBTestRouterContext.self)
        router.middlewares.add(HBLogRequestsMiddleware(.debug))
        router.put("/hello") { _, _ -> String in
            throw HBHTTPError(.badRequest)
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/hello", method: .PUT) { _ in
            }
        }
    }
}
