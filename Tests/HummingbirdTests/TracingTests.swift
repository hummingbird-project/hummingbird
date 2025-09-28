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

import Foundation
import HTTPTypes
import Hummingbird
import HummingbirdRouter
import HummingbirdTesting
import Testing
import Tracing

@testable import Instrumentation

struct TracingTests {
    static let testTracer = {
        let tracer = TaskUniqueTestTracer()
        InstrumentationSystem.bootstrap(tracer)
        return tracer
    }()

    @Test func testTracingMiddleware() async throws {
        try await Self.testTracer.withUnique {
            try await confirmation { endSpan in
                Self.testTracer.onEndSpan = { _ in endSpan() }

                let router = Router()
                router.middlewares.add(TracingMiddleware(attributes: ["net.host.name": "127.0.0.1", "net.host.port": 8080]))
                router.get("users/{id}") { _, _ -> String in
                    "42"
                }
                let app = Application(responder: router.buildResponder())
                try await app.test(.router) { client in
                    try await client.execute(uri: "/users/42", method: .get, headers: [.userAgent: "42"]) { response in
                        #expect(response.status == .ok)
                        #expect(String(buffer: response.body) == "42")
                    }
                }
            }

            let span = try #require(Self.testTracer.spans.first)

            #expect(span.operationName == "/users/{id}")
            #expect(span.kind == .server)
            #expect(span.status == nil)
            #expect(span.recordedErrors.isEmpty == true)

            expectSpanAttributesEqual(
                span.attributes,
                [
                    "http.request.method": "GET",
                    "http.route": "/users/{id}",
                    "url.path": "/users/42",
                    "http.response.status_code": 200,
                    "http.response.body.size": 2,
                    "net.host.name": "127.0.0.1",
                    "net.host.port": 8080,
                    "user_agent.original": "42",
                ]
            )
        }
    }

    @Test func testTracingMiddlewareWithRouterBuilder() async throws {
        try await Self.testTracer.withUnique {
            try await confirmation { endSpan in
                Self.testTracer.onEndSpan = { _ in endSpan() }

                let router = RouterBuilder(context: BasicRouterRequestContext.self) {
                    TracingMiddleware(attributes: ["net.host.name": "127.0.0.1", "net.host.port": 8080])
                    Get("users/{id}") { _, _ in "42" }
                }
                let app = Application(responder: router.buildResponder())
                try await app.test(.router) { client in
                    try await client.execute(uri: "/users/42", method: .get) { response in
                        #expect(response.status == .ok)
                        #expect(String(buffer: response.body) == "42")
                    }
                }
            }

            let span = try #require(Self.testTracer.spans.first)

            #expect(span.operationName == "/users/{id}")
            #expect(span.kind == .server)
            #expect(span.status == nil)
            #expect(span.recordedErrors.isEmpty == true)

            expectSpanAttributesEqual(
                span.attributes,
                [
                    "http.request.method": "GET",
                    "http.route": "/users/{id}",
                    "url.path": "/users/42",
                    "http.response.status_code": 200,
                    "http.response.body.size": 2,
                    "net.host.name": "127.0.0.1",
                    "net.host.port": 8080,
                ]
            )
        }
    }

    @Test func testTracingMiddlewareWithQueryParameters() async throws {
        try await Self.testTracer.withUnique {
            try await confirmation { endSpan in
                Self.testTracer.onEndSpan = { _ in endSpan() }

                let router = Router()
                router.middlewares.add(TracingMiddleware())
                router.get("users") { _, _ -> String in
                    "42"
                }
                let app = Application(responder: router.buildResponder())
                try await app.test(.router) { client in
                    try await client.execute(uri: "/users?q=42&s=asc", method: .get) { response in
                        #expect(response.status == .ok)
                        #expect(String(buffer: response.body) == "42")
                    }
                }
            }

            let span = try #require(Self.testTracer.spans.first)

            #expect(span.operationName == "/users")
            #expect(span.kind == .server)
            #expect(span.status == nil)
            #expect(span.recordedErrors.isEmpty)

            expectSpanAttributesEqual(
                span.attributes,
                [
                    "http.request.method": "GET",
                    "http.route": "/users",
                    "url.path": "/users",
                    "url.query": "q=42&s=asc",
                    "http.response.status_code": 200,
                    "http.response.body.size": 2,
                ]
            )

        }
    }

    @Test func testTracingMiddlewareWithRedactedQueryParameters() async throws {
        try await Self.testTracer.withUnique {
            try await confirmation { endSpan in
                Self.testTracer.onEndSpan = { _ in endSpan() }

                let router = Router()
                router.middlewares.add(TracingMiddleware(redactingQueryParameters: ["secret"]))
                router.get("users") { _, _ -> String in
                    "42"
                }
                let app = Application(responder: router.buildResponder())
                try await app.test(.router) { client in
                    try await client.execute(uri: "/users?q=42&secret=foo&s=asc", method: .get) { response in
                        #expect(response.status == .ok)
                        #expect(String(buffer: response.body) == "42")
                    }
                }
            }

            let span = try #require(Self.testTracer.spans.first)

            #expect(span.operationName == "/users")
            #expect(span.kind == .server)
            #expect(span.status == nil)
            #expect(span.recordedErrors.isEmpty)

            expectSpanAttributesEqual(
                span.attributes,
                [
                    "http.request.method": "GET",
                    "http.route": "/users",
                    "url.path": "/users",
                    "url.query": "q=42&secret=REDACTED&s=asc",
                    "http.response.status_code": 200,
                    "http.response.body.size": 2,
                ]
            )
        }
    }

    @Test func testTracingMiddlewareWithFile() async throws {
        let filename = "\(#function).jpg"
        let text = "Test file contents"
        let data = Data(text.utf8)
        let fileURL = URL(fileURLWithPath: filename)
        #expect(throws: Never.self) { try data.write(to: fileURL) }
        defer { #expect(throws: Never.self) { try FileManager.default.removeItem(at: fileURL) } }

        try await Self.testTracer.withUnique {
            try await confirmation { endSpan in
                Self.testTracer.onEndSpan = { _ in endSpan() }

                let router = RouterBuilder(context: BasicRouterRequestContext.self) {
                    TracingMiddleware(attributes: ["net.host.name": "127.0.0.1", "net.host.port": 8080])
                    FileMiddleware(".")
                }
                let app = Application(responder: router.buildResponder())
                try await app.test(.router) { client in
                    try await client.execute(uri: "/\(filename)", method: .get) { response in
                        #expect(response.headers[.contentLength] == text.count.description)
                    }
                }
            }
            let span = try #require(Self.testTracer.spans.first)

            #expect(span.operationName == "FileMiddleware")
            #expect(span.kind == .server)
            #expect(span.status == nil)
            #expect(span.recordedErrors.isEmpty == true)

            expectSpanAttributesEqual(
                span.attributes,
                [
                    "http.request.method": "GET",
                    "http.route": "FileMiddleware",
                    "url.path": "/\(filename)",
                    "http.response.status_code": 200,
                    "http.response.body.size": .int64(Int64(text.count)),
                    "net.host.name": "127.0.0.1",
                    "net.host.port": 8080,
                ]
            )
        }
    }

    @Test func testMiddlewareSkippingEndpoint() async throws {
        struct DeadendMiddleware<Context: RequestContext>: RouterMiddleware {
            func handle(_ input: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
                .init(status: .ok)
            }
        }
        try await Self.testTracer.withUnique {
            try await confirmation { endSpan in

                Self.testTracer.onEndSpan = { _ in endSpan() }

                let router = RouterBuilder(context: BasicRouterRequestContext.self) {
                    TracingMiddleware()
                    RouteGroup("test") {
                        DeadendMiddleware()
                        Get("this") { _, _ in "Hello" }
                    }
                }
                let app = Application(responder: router.buildResponder())
                try await app.test(.router) { client in
                    try await client.execute(uri: "/test/this", method: .get) { response in
                        #expect(response.status == .ok)
                    }
                }
            }
            let span = try #require(Self.testTracer.spans.first)

            #expect(span.operationName == "/test")
            #expect(span.kind == .server)
            #expect(span.status == nil)
            #expect(span.recordedErrors.isEmpty == true)

            expectSpanAttributesEqual(
                span.attributes,
                [
                    "http.request.method": "GET",
                    "http.route": "/test",
                    "url.path": "/test/this",
                    "http.response.status_code": 200,
                    "http.response.body.size": 0,
                ]
            )
        }
    }

    @Test func testTracingMiddlewareServerError() async throws {
        try await Self.testTracer.withUnique {
            try await confirmation { endSpan in
                Self.testTracer.onEndSpan = { _ in endSpan() }

                let router = Router()
                router.middlewares.add(TracingMiddleware())
                router.post("users") { _, _ -> String in
                    throw HTTPError(.internalServerError)
                }
                let app = Application(responder: router.buildResponder())
                try await app.test(.router) { client in
                    try await client.execute(uri: "/users", method: .post, headers: [.contentLength: "2"], body: ByteBuffer(string: "42")) {
                        response in
                        #expect(response.status == .internalServerError)
                    }
                }
            }
            let span = try #require(Self.testTracer.spans.first)

            #expect(span.operationName == "/users")
            #expect(span.kind == .server)
            #expect(span.status == .init(code: .error))

            #expect(span.recordedErrors.count == 1)
            let error = try #require(span.recordedErrors.first?.0 as? HTTPError, "Recorded unexpected errors: \(span.recordedErrors)")
            #expect(error.status == .internalServerError)

            expectSpanAttributesEqual(
                span.attributes,
                [
                    "http.request.method": "POST",
                    "http.route": "/users",
                    "url.path": "/users",
                    "http.response.status_code": 500,
                    "http.request.body.size": 2,
                ]
            )
        }
    }

    @Test func testTracingMiddlewareIncludingHeaders() async throws {
        try await Self.testTracer.withUnique {
            try await confirmation { endSpan in
                Self.testTracer.onEndSpan = { _ in endSpan() }

                let router = Router()
                router.middlewares.add(
                    TracingMiddleware(recordingHeaders: [
                        .accept, .contentType, .cacheControl, .test,
                    ])
                )
                router.get("users/{id}") { _, _ -> Response in
                    var headers = HTTPFields()
                    headers[values: .cacheControl] = ["86400", "public"]
                    headers[.contentType] = "text/plain"
                    return Response(
                        status: .ok,
                        headers: headers,
                        body: .init(byteBuffer: ByteBuffer(string: "42"))
                    )
                }
                let app = Application(responder: router.buildResponder())
                try await app.test(.router) { client in
                    var requestHeaders = HTTPFields()
                    requestHeaders[values: .accept] = ["text/plain", "application/json"]
                    requestHeaders[.cacheControl] = "no-cache"
                    try await client.execute(uri: "/users/42", method: .get, headers: requestHeaders) { response in
                        #expect(response.status == .ok)
                        #expect(String(buffer: response.body) == "42")
                    }
                }
            }
            let span = try #require(Self.testTracer.spans.first)

            #expect(span.operationName == "/users/{id}")
            #expect(span.kind == .server)
            #expect(span.status == nil)
            #expect(span.recordedErrors.isEmpty == true)

            expectSpanAttributesEqual(
                span.attributes,
                [
                    "http.request.method": "GET",
                    "http.route": "/users/{id}",
                    "url.path": "/users/42",
                    "http.response.status_code": 200,
                    "http.response.body.size": 2,
                    "http.request.header.accept": .stringArray(["text/plain", "application/json"]),
                    "http.request.header.cache_control": "no-cache",
                    "http.response.header.content_type": "text/plain",
                    "http.response.header.cache_control": .stringArray(["86400", "public"]),
                ]
            )
        }
    }

    @Test func testTracingMiddlewareEmptyResponse() async throws {

        try await Self.testTracer.withUnique {
            try await confirmation { endSpan in
                Self.testTracer.onEndSpan = { _ in endSpan() }

                let router = Router()
                router.middlewares.add(TracingMiddleware())
                router.post("/users") { _, _ -> HTTPResponse.Status in
                    .noContent
                }
                let app = Application(responder: router.buildResponder())
                try await app.test(.router) { client in
                    try await client.execute(uri: "/users", method: .post) { response in
                        #expect(response.status == .noContent)
                    }
                }
            }
            let span = try #require(Self.testTracer.spans.first)

            #expect(span.operationName == "/users")
            #expect(span.kind == .server)
            #expect(span.status == nil)
            #expect(span.recordedErrors.isEmpty == true)

            expectSpanAttributesEqual(
                span.attributes,
                [
                    "http.request.method": "POST",
                    "http.route": "/users",
                    "url.path": "/users",
                    "http.response.status_code": 204,
                    "http.response.body.size": 0,
                ]
            )
        }
    }

    @Test func testTracingMiddlewareIndexRoute() async throws {
        try await Self.testTracer.withUnique {
            try await confirmation { endSpan in
                Self.testTracer.onEndSpan = { _ in endSpan() }

                let router = Router()
                router.middlewares.add(TracingMiddleware())
                router.get("/") { _, _ -> HTTPResponse.Status in
                    .ok
                }
                let app = Application(responder: router.buildResponder())
                try await app.test(.router) { client in
                    try await client.execute(uri: "/", method: .get) { response in
                        #expect(response.status == .ok)
                    }
                }
            }
            let span = try #require(Self.testTracer.spans.first)

            #expect(span.operationName == "/")
            #expect(span.kind == .server)
            #expect(span.status == nil)
            #expect(span.recordedErrors.isEmpty == true)

            expectSpanAttributesEqual(
                span.attributes,
                [
                    "http.request.method": "GET",
                    "http.route": "/",
                    "url.path": "/",
                    "http.response.status_code": 200,
                    "http.response.body.size": 0,
                ]
            )
        }
    }

    @Test func testTracingMiddlewareRouteNotFound() async throws {
        try await Self.testTracer.withUnique {
            try await confirmation { endSpan in
                Self.testTracer.onEndSpan = { _ in endSpan() }

                let router = Router()
                router.middlewares.add(TracingMiddleware())
                let app = Application(responder: router.buildResponder())
                try await app.test(.router) { client in
                    try await client.execute(uri: "/", method: .get) { response in
                        #expect(response.status == .notFound)
                    }
                }
            }
            let span = try #require(Self.testTracer.spans.first)

            #expect(span.operationName == "HTTP GET route not found")
            #expect(span.kind == .server)
            #expect(span.status == nil)

            #expect(span.recordedErrors.count == 1)
            let error = try #require(span.recordedErrors.first?.0 as? HTTPError, "Recorded unexpected errors: \(span.recordedErrors)")
            #expect(error.status == .notFound)

            expectSpanAttributesEqual(
                span.attributes,
                [
                    "http.request.method": "GET",
                    "url.path": "/",
                    "http.response.status_code": 404,
                ]
            )
        }
    }

    /// Test span is ended even if the response body with the span end is not run
    @Test func testTracingMiddlewareDropResponse() async throws {
        struct ErrorMiddleware<Context: RequestContext>: RouterMiddleware {
            public func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
                _ = try await next(request, context)
                throw HTTPError(.badRequest)
            }
        }

        try await Self.testTracer.withUnique {
            try await confirmation { endSpan in
                Self.testTracer.onEndSpan = { _ in endSpan() }

                let router = Router()
                router.middlewares.add(ErrorMiddleware())
                router.middlewares.add(TracingMiddleware())
                router.get("users/:id") { _, _ -> String in
                    "42"
                }
                let app = Application(responder: router.buildResponder())
                try await app.test(.router) { client in
                    try await client.execute(uri: "/users/42", method: .get) { response in
                        #expect(response.status == .badRequest)
                    }
                }
            }
            let span = try #require(Self.testTracer.spans.first)

            #expect(span.operationName == "/users/{id}")
            #expect(span.kind == .server)
            #expect(span.status == nil)
            #expect(span.recordedErrors.isEmpty == true)
        }
    }

    // Test span length is the time it takes to write the response
    @Test func testTracingSpanLength() async throws {
        try await Self.testTracer.withUnique {
            try await confirmation { endSpan in
                Self.testTracer.onEndSpan = { _ in endSpan() }

                let router = Router()
                router.middlewares.add(TracingMiddleware())
                router.get("users/:id") { _, _ -> Response in
                    Response(
                        status: .ok,
                        body: .init { _ in try await Task.sleep(for: .milliseconds(100)) }
                    )
                }
                let app = Application(responder: router.buildResponder())
                try await app.test(.router) { client in
                    try await client.execute(uri: "/users/42", method: .get) { response in
                        #expect(response.status == .ok)
                    }
                }
            }
            let span = try #require(Self.testTracer.spans.first)
            // Test tracer records span times in milliseconds
            #expect(span.endTime! - span.startTime > 100)
        }
    }

    /// Test tracing serviceContext is attached to request when route handler is called
    @Test func testServiceContextPropagation() async throws {
        try await Self.testTracer.withUnique {
            try await confirmation(expectedCount: 2) { endSpan in
                Self.testTracer.onEndSpan = { _ in endSpan() }

                let router = Router()
                router.middlewares.add(TracingMiddleware())
                router.get("/") { _, _ -> HTTPResponse.Status in
                    var serviceContext = ServiceContext.current ?? ServiceContext.topLevel
                    serviceContext.testID = "test"
                    let span = InstrumentationSystem.tracer.startSpan("testing", context: serviceContext, ofKind: .server)
                    span.end()
                    return .ok
                }
                let app = Application(responder: router.buildResponder())
                try await app.test(.router) { client in
                    try await client.execute(uri: "/", method: .get) { response in
                        #expect(response.status == .ok)
                    }
                }
            }
            #expect(Self.testTracer.spans.count == 2)
            let span = Self.testTracer.spans[0]
            let span2 = Self.testTracer.spans[1]

            #expect(span2.context.testID == "test")
            #expect(span2.context.traceID == span.context.traceID)
        }
    }

    /// Verify serviceContext set in trace middleware propagates to routes
    @Test func testServiceContextPropagationWithSpan() async throws {
        try await Self.testTracer.withUnique {
            try await confirmation(expectedCount: 2) { endSpan in
                Self.testTracer.onEndSpan = { _ in endSpan() }

                let router = Router()
                router.middlewares.add(TracingMiddleware())
                router.get("/") { _, _ -> HTTPResponse.Status in
                    var serviceContext = ServiceContext.current ?? ServiceContext.topLevel
                    serviceContext.testID = "test"
                    return InstrumentationSystem.tracer.withSpan("TestSpan", context: serviceContext, ofKind: .client) { span in
                        span.attributes["test-attribute"] = 42
                        return .ok
                    }
                }
                let app = Application(responder: router.buildResponder())
                try await app.test(.router) { client in
                    try await client.execute(uri: "/", method: .get) { response in
                        #expect(response.status == .ok)
                    }
                }
            }
            #expect(Self.testTracer.spans.count == 2)
            let span = Self.testTracer.spans[0]
            let span2 = Self.testTracer.spans[1]

            #expect(span2.context.testID == "test")
            #expect(span2.attributes["test-attribute"]?.toSpanAttribute() == 42)
            #expect(span2.context.traceID == span.context.traceID)
        }
    }

    /// And SpanMiddleware in front of tracing middleware and set serviceContext value and use
    /// EventLoopFuture version of `request.withSpan` to call next.respond
    @Test func testServiceContextPropagationInMiddleware() async throws {
        struct SpanMiddleware<Context: RequestContext>: RouterMiddleware {
            public func handle(
                _ request: Request,
                context: Context,
                next: (Request, Context) async throws -> Response
            ) async throws -> Response {
                var serviceContext = ServiceContext.current ?? ServiceContext.topLevel
                serviceContext.testID = "testMiddleware"

                return try await InstrumentationSystem.tracer.withSpan("TestSpan", context: serviceContext, ofKind: .server) { _ in
                    try await next(request, context)
                }
            }
        }

        try await Self.testTracer.withUnique {
            try await confirmation(expectedCount: 2) { endSpan in
                Self.testTracer.onEndSpan = { _ in endSpan() }

                let router = Router()
                router.middlewares.add(SpanMiddleware())
                router.middlewares.add(TracingMiddleware())
                router.get("/") { _, _ -> HTTPResponse.Status in
                    try await Task.sleep(for: .milliseconds(2))
                    return .ok
                }
                let app = Application(responder: router.buildResponder())
                try await app.test(.router) { client in
                    try await client.execute(uri: "/", method: .get) { response in
                        #expect(response.status == .ok)
                    }
                }
            }
            #expect(Self.testTracer.spans.count == 2)
            let span2 = Self.testTracer.spans[1]

            #expect(span2.context.testID == "testMiddleware")
        }
    }

    /// Test tracing middleware serviceContext is propagated to async route handlers
    @Test func testServiceContextPropagationAsync() async throws {
        try await Self.testTracer.withUnique {
            try await confirmation(expectedCount: 2) { endSpan in
                Self.testTracer.onEndSpan = { _ in endSpan() }

                let router = Router()
                router.middlewares.add(TracingMiddleware())
                router.get("/") { _, _ -> HTTPResponse.Status in
                    try await Task.sleep(nanoseconds: 1000)
                    return InstrumentationSystem.tracer.withAnySpan("testing", ofKind: .server) { _ in
                        .ok
                    }
                }
                let app = Application(responder: router.buildResponder())
                try await app.test(.router) { client in
                    try await client.execute(uri: "/", method: .get) { response in
                        #expect(response.status == .ok)
                    }
                }
            }
            #expect(Self.testTracer.spans.count == 2)
            let span = Self.testTracer.spans[0]
            let span2 = Self.testTracer.spans[1]

            #expect(span2.context.traceID == span.context.traceID)
        }
    }
}

/// TestID Key used in tests
internal enum TestIDKey: ServiceContextKey {
    typealias Value = String
    static var nameOverride: String? { "test-id" }
}

extension ServiceContext {
    /// extend ServiceContext to easily access test id
    var testID: String? {
        get {
            self[TestIDKey.self]
        }
        set {
            self[TestIDKey.self] = newValue
        }
    }
}

private func expectSpanAttributesEqual(
    _ lhs: @autoclosure () -> SpanAttributes,
    _ rhs: @autoclosure () -> [String: SpanAttribute],
    fileID: String = #fileID,
    filePath: String = #filePath,
    line: Int = #line,
    column: Int = #column
) {
    var rhs = rhs()

    // swift-format-ignore: ReplaceForEachWithForLoop
    lhs().forEach { key, attribute in
        if let rhsValue = rhs.removeValue(forKey: key) {
            #expect(rhsValue == attribute, sourceLocation: .init(fileID: fileID, filePath: filePath, line: line, column: column))
        } else {
            Issue.record(
                #"Did not specify expected value for "\#(key)", actual value is "\#(attribute)"."#,
                sourceLocation: .init(fileID: fileID, filePath: filePath, line: line, column: column)
            )
        }
    }

    if !rhs.isEmpty {
        Issue.record(
            #"Expected attributes "\#(rhs.keys)" are not present in actual attributes."#,
            sourceLocation: .init(fileID: fileID, filePath: filePath, line: line, column: column)
        )
    }
}
