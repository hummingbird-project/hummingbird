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

import HTTPTypes
import Hummingbird
import HummingbirdRouter
import HummingbirdTesting
import Logging
import NIOCore
import XCTest

final class MiddlewareTests: XCTestCase {
    static func randomBuffer(size: Int) -> ByteBuffer {
        var data = [UInt8](repeating: 0, count: size)
        data = data.map { _ in UInt8.random(in: 0...255) }
        return ByteBufferAllocator().buffer(bytes: data)
    }

    func testMiddleware() async throws {
        struct TestMiddleware<Context: RequestContext>: RouterMiddleware {
            func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
                var response = try await next(request, context)
                response.headers[.middleware] = "TestMiddleware"
                return response
            }
        }
        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            TestMiddleware()
            Get("/hello") { _, _ -> String in
                "Hello"
            }
        }
        let app = Application(responder: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "/hello", method: .get) { response in
                XCTAssertEqual(response.headers[.middleware], "TestMiddleware")
            }
        }
    }

    func testMiddlewareOrder() async throws {
        struct TestMiddleware<Context: RequestContext>: RouterMiddleware {
            let string: String
            func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
                var response = try await next(request, context)
                response.headers[values: .middleware].append(self.string)
                return response
            }
        }
        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            TestMiddleware(string: "first")
            TestMiddleware(string: "second")
            Get("/hello") { _, _ -> String in
                "Hello"
            }
        }
        let app = Application(responder: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "/hello", method: .get) { response in
                // headers come back in opposite order as middleware is applied to responses in that order
                XCTAssertEqual(response.headers[values: .middleware].first, "second")
                XCTAssertEqual(response.headers[values: .middleware].last, "first")
            }
        }
    }

    func testMiddlewareRunOnce() async throws {
        struct TestMiddleware<Context: RequestContext>: RouterMiddleware {
            func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
                var response = try await next(request, context)
                XCTAssertNil(response.headers[.alreadyRun])
                response.headers[.alreadyRun] = "true"
                return response
            }
        }
        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            TestMiddleware()
            Get("/hello") { _, _ -> String in
                "Hello"
            }
        }
        let app = Application(responder: router)
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
        struct TestMiddleware<Context: RequestContext>: RouterMiddleware {
            func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
                do {
                    return try await next(request, context)
                } catch let error as HTTPError where error.status == .notFound {
                    throw HTTPError(.notFound, message: "Edited error")
                }
            }
        }
        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            TestMiddleware()
        }
        let app = Application(responder: router)

        try await app.test(.router) { client in
            try await client.execute(uri: "/hello", method: .get) { response in
                XCTAssertEqual(response.status, .notFound)
                let error = try JSONDecoder().decodeByteBuffer(ErrorMessage.self, from: response.body)
                XCTAssertEqual(error.error.message, "Edited error")
            }
        }
    }

    func testMiddlewareResponseBodyWriter() async throws {
        struct TransformWriter: ResponseBodyWriter {
            var parentWriter: any ResponseBodyWriter

            mutating func write(_ buffer: ByteBuffer) async throws {
                let output = ByteBuffer(bytes: buffer.readableBytesView.map { $0 ^ 255 })
                try await self.parentWriter.write(output)
            }

            consuming func finish(_ trailingHeaders: HTTPFields?) async throws {
                var trailingHeaders = trailingHeaders ?? [:]
                trailingHeaders[.middleware2] = "test2"
                try await self.parentWriter.finish(trailingHeaders)
            }
        }
        struct TransformMiddleware<Context: RequestContext>: RouterMiddleware {
            func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
                let response = try await next(request, context)
                var editedResponse = response
                editedResponse.body = .init { writer in
                    let transformWriter = TransformWriter(parentWriter: writer)
                    try await response.body.write(transformWriter)
                }
                return editedResponse
            }
        }
        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            RouteGroup("") {
                TransformMiddleware()
                Get("test") { request, _ in
                    Response(
                        status: .ok,
                        body: .init { writer in
                            try await writer.write(request.body)
                            try await writer.finish([.middleware: "test"])
                        }
                    )
                }
            }
        }
        let app = Application(responder: router)

        try await app.test(.router) { client in
            let buffer = Self.randomBuffer(size: 64000)
            try await client.execute(uri: "/test", method: .get, body: buffer) { response in
                XCTAssertEqual(response.trailerHeaders?[.middleware], "test")
                XCTAssertEqual(response.trailerHeaders?[.middleware2], "test2")
                let expectedOutput = ByteBuffer(bytes: buffer.readableBytesView.map { $0 ^ 255 })
                XCTAssertEqual(expectedOutput, response.body)
            }
        }
    }
}

/// HTTPField used during tests
extension HTTPField.Name {
    static let middleware = Self("middleware")!
    static let middleware2 = Self("middleware2")!
    static let alreadyRun = Self("already-run")!
}
