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
import HummingbirdXCT
import Logging
import NIOCore
import XCTest

final class MiddlewareTests: XCTestCase {
    func randomBuffer(size: Int) -> ByteBuffer {
        var data = [UInt8](repeating: 0, count: size)
        data = data.map { _ in UInt8.random(in: 0...255) }
        return ByteBufferAllocator().buffer(bytes: data)
    }

    func testMiddleware() async throws {
        struct TestMiddleware<Context: HBBaseRequestContext>: HBMiddlewareProtocol {
            func handle(_ request: HBRequest, context: Context, next: (HBRequest, Context) async throws -> HBResponse) async throws -> HBResponse {
                var response = try await next(request, context)
                response.headers[.middleware] = "TestMiddleware"
                return response
            }
        }
        let router = HBRouterBuilder(context: HBBasicRouterRequestContext.self) {
            TestMiddleware()
            Get("/hello") { _, _ -> String in
                return "Hello"
            }
        }
        let app = HBApplication(responder: router)
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/hello", method: .get) { response in
                XCTAssertEqual(response.headers[.middleware], "TestMiddleware")
            }
        }
    }

    func testMiddlewareOrder() async throws {
        struct TestMiddleware<Context: HBBaseRequestContext>: HBMiddlewareProtocol {
            let string: String
            func handle(_ request: HBRequest, context: Context, next: (HBRequest, Context) async throws -> HBResponse) async throws -> HBResponse {
                var response = try await next(request, context)
                response.headers[values: .middleware].append(self.string)
                return response
            }
        }
        let router = HBRouterBuilder(context: HBBasicRouterRequestContext.self) {
            TestMiddleware(string: "first")
            TestMiddleware(string: "second")
            Get("/hello") { _, _ -> String in
                return "Hello"
            }
        }
        let app = HBApplication(responder: router)
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/hello", method: .get) { response in
                // headers come back in opposite order as middleware is applied to responses in that order
                XCTAssertEqual(response.headers[values: .middleware].first, "second")
                XCTAssertEqual(response.headers[values: .middleware].last, "first")
            }
        }
    }

    func testMiddlewareRunOnce() async throws {
        struct TestMiddleware<Context: HBBaseRequestContext>: HBMiddlewareProtocol {
            func handle(_ request: HBRequest, context: Context, next: (HBRequest, Context) async throws -> HBResponse) async throws -> HBResponse {
                var response = try await next(request, context)
                XCTAssertNil(response.headers[.alreadyRun])
                response.headers[.alreadyRun] = "true"
                return response
            }
        }
        let router = HBRouterBuilder(context: HBBasicRouterRequestContext.self) {
            TestMiddleware()
            Get("/hello") { _, _ -> String in
                return "Hello"
            }
        }
        let app = HBApplication(responder: router)
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/hello", method: .get) { _ in
            }
        }
    }

    func testMiddlewareRunWhenNoRouteFound() async throws {
        struct TestMiddleware<Context: HBBaseRequestContext>: HBMiddlewareProtocol {
            func handle(_ request: HBRequest, context: Context, next: (HBRequest, Context) async throws -> HBResponse) async throws -> HBResponse {
                do {
                    return try await next(request, context)
                } catch let error as HBHTTPError where error.status == .notFound {
                    throw HBHTTPError(.notFound, message: "Edited error")
                }
            }
        }
        let router = HBRouterBuilder(context: HBBasicRouterRequestContext.self) {
            TestMiddleware()
        }
        let app = HBApplication(responder: router)

        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/hello", method: .get) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "Edited error")
                XCTAssertEqual(response.status, .notFound)
            }
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
        struct TransformMiddleware<Context: HBBaseRequestContext>: HBMiddlewareProtocol {
            func handle(_ request: HBRequest, context: Context, next: (HBRequest, Context) async throws -> HBResponse) async throws -> HBResponse {
                let response = try await next(request, context)
                var editedResponse = response
                editedResponse.body = .init { writer in
                    let transformWriter = TransformWriter(parentWriter: writer, allocator: context.allocator)
                    let tailHeaders = try await response.body.write(transformWriter)
                    return tailHeaders
                }
                return editedResponse
            }
        }
        let router = HBRouterBuilder(context: HBBasicRouterRequestContext.self) {
            RouteGroup {
                TransformMiddleware()
                Get("test") { request, _ in
                    return HBResponse(status: .ok, body: .init(asyncSequence: request.body))
                }
            }
        }
        let app = HBApplication(responder: router)

        try await app.test(.router) { client in
            let buffer = self.randomBuffer(size: 64000)
            try await client.XCTExecute(uri: "/test", method: .get, body: buffer) { response in
                let expectedOutput = ByteBuffer(bytes: buffer.readableBytesView.map { $0 ^ 255 })
                XCTAssertEqual(expectedOutput, response.body)
            }
        }
    }
}

/// HTTPField used during tests
extension HTTPField.Name {
    static let middleware = Self("middleware")!
    static let alreadyRun = Self("already-run")!
}
