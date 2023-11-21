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

import Hummingbird
import HummingbirdXCT
@testable import Instrumentation
import Tracing
import XCTest

final class TracingTests: XCTestCase {
    func wait(for expectations: [XCTestExpectation], timeout: TimeInterval) async {
        #if os(Linux) || swift(<5.8)
        super.wait(for: expectations, timeout: timeout)
        #else
        await fulfillment(of: expectations, timeout: timeout)
        #endif
    }

    func testTracingMiddleware() async throws {
        let expectation = expectation(description: "Expected span to be ended.")

        let tracer = TestTracer()
        tracer.onEndSpan = { _ in expectation.fulfill() }
        InstrumentationSystem.bootstrapInternal(tracer)

        let router = HBRouterBuilder(context: HBTestRouterContext.self)
        router.middlewares.add(HBTracingMiddleware())
        router.get("users/:id") { _, _ -> String in
            return "42"
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/users/42", method: .GET) { response in
                XCTAssertEqual(response.status, .ok)
                var responseBody = try XCTUnwrap(response.body)
                XCTAssertEqual(responseBody.readString(length: responseBody.readableBytes), "42")
            }
        }

        await self.wait(for: [expectation], timeout: 1)

        let span = try XCTUnwrap(tracer.spans.first)

        XCTAssertEqual(span.operationName, "/users/:id")
        XCTAssertEqual(span.kind, .server)
        XCTAssertNil(span.status)
        XCTAssertTrue(span.recordedErrors.isEmpty)

        XCTAssertSpanAttributesEqual(span.attributes, [
            "http.method": "GET",
            "http.target": "/users/42",
            "http.status_code": 200,
            "http.response_content_length": 2,
            "net.host.name": "127.0.0.1",
            "net.host.port": 8080,
            "http.flavor": "1.1",
        ])
    }

    func testTracingMiddlewareServerError() async throws {
        let expectation = expectation(description: "Expected span to be ended.")

        let tracer = TestTracer()
        tracer.onEndSpan = { _ in expectation.fulfill() }
        InstrumentationSystem.bootstrapInternal(tracer)

        let router = HBRouterBuilder(context: HBTestRouterContext.self)
        router.middlewares.add(HBTracingMiddleware())
        router.post("users") { _, _ -> String in
            throw HBHTTPError(.internalServerError)
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/users", method: .POST, headers: ["content-length": "2"], body: ByteBuffer(string: "42")) { response in
                XCTAssertEqual(response.status, .internalServerError)
            }
        }

        await self.wait(for: [expectation], timeout: 1)

        let span = try XCTUnwrap(tracer.spans.first)

        XCTAssertEqual(span.operationName, "/users")
        XCTAssertEqual(span.kind, .server)
        XCTAssertEqual(span.status, .init(code: .error))

        XCTAssertEqual(span.recordedErrors.count, 1)
        let error = try XCTUnwrap(span.recordedErrors.first?.0 as? HBHTTPError, "Recorded unexpected errors: \(span.recordedErrors)")
        XCTAssertEqual(error.status, .internalServerError)

        XCTAssertSpanAttributesEqual(span.attributes, [
            "http.method": "POST",
            "http.target": "/users",
            "http.status_code": 500,
            "http.request_content_length": 2,
            "net.host.name": "127.0.0.1",
            "net.host.port": 8080,
            "http.flavor": "1.1",
        ])
    }

    func testTracingMiddlewareIncludingHeaders() async throws {
        let expectation = expectation(description: "Expected span to be ended.")

        let tracer = TestTracer()
        tracer.onEndSpan = { _ in expectation.fulfill() }
        InstrumentationSystem.bootstrapInternal(tracer)

        let router = HBRouterBuilder(context: HBTestRouterContext.self)
        router.middlewares.add(HBTracingMiddleware(recordingHeaders: [
            "accept", "content-type", "cache-control", "does-not-exist",
        ]))
        router.get("users/:id") { _, _ -> HBResponse in
            var headers = HTTPHeaders()
            headers.add(name: "cache-control", value: "86400")
            headers.add(name: "cache-control", value: "public")
            headers.add(name: "content-type", value: "text/plain")
            return HBResponse(
                status: .ok,
                headers: headers,
                body: .init(byteBuffer: ByteBuffer(string: "42"))
            )
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in
            var requestHeaders = HTTPHeaders()
            requestHeaders.add(name: "Accept", value: "text/plain")
            requestHeaders.add(name: "Accept", value: "application/json")
            requestHeaders.add(name: "Cache-Control", value: "no-cache")
            try await client.XCTExecute(uri: "/users/42", method: .GET, headers: requestHeaders) { response in
                XCTAssertEqual(response.status, .ok)
                var responseBody = try XCTUnwrap(response.body)
                XCTAssertEqual(responseBody.readString(length: responseBody.readableBytes), "42")
            }
        }

        await self.wait(for: [expectation], timeout: 1)

        let span = try XCTUnwrap(tracer.spans.first)

        XCTAssertEqual(span.operationName, "/users/:id")
        XCTAssertEqual(span.kind, .server)
        XCTAssertNil(span.status)
        XCTAssertTrue(span.recordedErrors.isEmpty)

        XCTAssertSpanAttributesEqual(span.attributes, [
            "http.method": "GET",
            "http.target": "/users/42",
            "http.status_code": 200,
            "http.response_content_length": 2,
            "net.host.name": "127.0.0.1",
            "net.host.port": 8080,
            "http.flavor": "1.1",
            "http.request.header.accept": .stringArray(["text/plain", "application/json"]),
            "http.request.header.cache_control": "no-cache",
            "http.response.header.content_type": "text/plain",
            "http.response.header.cache_control": .stringArray(["86400", "public"]),
        ])
    }

    func testTracingMiddlewareEmptyResponse() async throws {
        let expectation = expectation(description: "Expected span to be ended.")

        let tracer = TestTracer()
        tracer.onEndSpan = { _ in expectation.fulfill() }
        InstrumentationSystem.bootstrapInternal(tracer)

        let router = HBRouterBuilder(context: HBTestRouterContext.self)
        router.middlewares.add(HBTracingMiddleware())
        router.post("/users") { _, _ -> HTTPResponseStatus in
            return .noContent
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/users", method: .POST) { response in
                XCTAssertEqual(response.status, .noContent)
            }
        }

        await self.wait(for: [expectation], timeout: 1)

        let span = try XCTUnwrap(tracer.spans.first)

        XCTAssertEqual(span.operationName, "/users")
        XCTAssertEqual(span.kind, .server)
        XCTAssertNil(span.status)
        XCTAssertTrue(span.recordedErrors.isEmpty)

        XCTAssertSpanAttributesEqual(span.attributes, [
            "http.method": "POST",
            "http.target": "/users",
            "http.status_code": 204,
            "http.response_content_length": 0,
            "net.host.name": "127.0.0.1",
            "net.host.port": 8080,
            "http.flavor": "1.1",
        ])
    }

    func testTracingMiddlewareIndexRoute() async throws {
        let expectation = expectation(description: "Expected span to be ended.")

        let tracer = TestTracer()
        tracer.onEndSpan = { _ in expectation.fulfill() }
        InstrumentationSystem.bootstrapInternal(tracer)

        let router = HBRouterBuilder(context: HBTestRouterContext.self)
        router.middlewares.add(HBTracingMiddleware())
        router.get("/") { _, _ -> HTTPResponseStatus in
            return .ok
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/", method: .GET) { response in
                XCTAssertEqual(response.status, .ok)
            }
        }

        await self.wait(for: [expectation], timeout: 1)

        let span = try XCTUnwrap(tracer.spans.first)

        XCTAssertEqual(span.operationName, "/")
        XCTAssertEqual(span.kind, .server)
        XCTAssertNil(span.status)
        XCTAssertTrue(span.recordedErrors.isEmpty)

        XCTAssertSpanAttributesEqual(span.attributes, [
            "http.method": "GET",
            "http.target": "/",
            "http.status_code": 200,
            "http.response_content_length": 0,
            "net.host.name": "127.0.0.1",
            "net.host.port": 8080,
            "http.flavor": "1.1",
        ])
    }

    func testTracingMiddlewareRouteNotFound() async throws {
        let expectation = expectation(description: "Expected span to be ended.")

        let tracer = TestTracer()
        tracer.onEndSpan = { _ in expectation.fulfill() }
        InstrumentationSystem.bootstrapInternal(tracer)

        let router = HBRouterBuilder(context: HBTestRouterContext.self)
        router.middlewares.add(HBTracingMiddleware())
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/", method: .GET) { response in
                XCTAssertEqual(response.status, .notFound)
            }
        }
        await self.wait(for: [expectation], timeout: 1)

        let span = try XCTUnwrap(tracer.spans.first)

        XCTAssertEqual(span.operationName, "HTTP GET route not found")
        XCTAssertEqual(span.kind, .server)
        XCTAssertNil(span.status)

        XCTAssertEqual(span.recordedErrors.count, 1)
        let error = try XCTUnwrap(span.recordedErrors.first?.0 as? HBHTTPError, "Recorded unexpected errors: \(span.recordedErrors)")
        XCTAssertEqual(error.status, .notFound)

        XCTAssertSpanAttributesEqual(span.attributes, [
            "http.method": "GET",
            "http.target": "/",
            "http.status_code": 404,
            "net.host.name": "127.0.0.1",
            "net.host.port": 8080,
            "http.flavor": "1.1",
        ])
    }

    /// Test tracing serviceContext is attached to request when route handler is called
    func testServiceContextPropagation() async throws {
        let expectation = expectation(description: "Expected span to be ended.")
        expectation.expectedFulfillmentCount = 2

        let tracer = TestTracer()
        tracer.onEndSpan = { _ in expectation.fulfill() }
        InstrumentationSystem.bootstrapInternal(tracer)

        let router = HBRouterBuilder(context: HBTestRouterContext.self)
        router.middlewares.add(HBTracingMiddleware())
        router.get("/") { _, _ -> HTTPResponseStatus in
            var serviceContext = ServiceContext.current ?? ServiceContext.topLevel
            serviceContext.testID = "test"
            let span = InstrumentationSystem.tracer.startSpan("testing", context: serviceContext, ofKind: .server)
            span.end()
            return .ok
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/", method: .GET) { response in
                XCTAssertEqual(response.status, .ok)
            }
        }
        await self.wait(for: [expectation], timeout: 1)

        XCTAssertEqual(tracer.spans.count, 2)
        let span = tracer.spans[0]
        let span2 = tracer.spans[1]

        XCTAssertEqual(span2.context.testID, "test")
        XCTAssertEqual(span2.context.traceID, span.context.traceID)
    }

    /// Verify serviceContext set in trace middleware propagates to routes
    func testServiceContextPropagationWithSpan() async throws {
        let expectation = expectation(description: "Expected span to be ended.")
        expectation.expectedFulfillmentCount = 2

        let tracer = TestTracer()
        tracer.onEndSpan = { _ in expectation.fulfill() }
        InstrumentationSystem.bootstrapInternal(tracer)

        let router = HBRouterBuilder(context: HBTestRouterContext.self)
        router.middlewares.add(HBTracingMiddleware())
        router.get("/") { _, _ -> HTTPResponseStatus in
            var serviceContext = ServiceContext.current ?? ServiceContext.topLevel
            serviceContext.testID = "test"
            return InstrumentationSystem.tracer.withSpan("TestSpan", context: serviceContext, ofKind: .client) { span in
                span.attributes["test-attribute"] = 42
                return .ok
            }
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/", method: .GET) { response in
                XCTAssertEqual(response.status, .ok)
            }
        }

        await self.wait(for: [expectation], timeout: 1)

        XCTAssertEqual(tracer.spans.count, 2)
        let span = tracer.spans[0]
        let span2 = tracer.spans[1]

        XCTAssertEqual(span2.context.testID, "test")
        XCTAssertEqual(span2.attributes["test-attribute"]?.toSpanAttribute(), 42)
        XCTAssertEqual(span2.context.traceID, span.context.traceID)
    }

    /// And SpanMiddleware in front of tracing middleware and set serviceContext value and use
    /// EventLoopFuture version of `request.withSpan` to call next.respond
    func testServiceContextPropagationInMiddleware() async throws {
        let expectation = expectation(description: "Expected span to be ended.")
        expectation.expectedFulfillmentCount = 2

        struct SpanMiddleware<Context: HBBaseRequestContext>: HBMiddleware {
            public func apply(to request: HBRequest, context: Context, next: any HBResponder<Context>) async throws -> HBResponse {
                var serviceContext = ServiceContext.current ?? ServiceContext.topLevel
                serviceContext.testID = "testMiddleware"

                return try await InstrumentationSystem.tracer.withSpan("TestSpan", context: serviceContext, ofKind: .server) { _ in
                    try await next.respond(to: request, context: context)
                }
            }
        }

        let tracer = TestTracer()
        tracer.onEndSpan = { _ in
            expectation.fulfill()
        }
        InstrumentationSystem.bootstrapInternal(tracer)

        let router = HBRouterBuilder(context: HBTestRouterContext.self)
        router.middlewares.add(SpanMiddleware())
        router.middlewares.add(HBTracingMiddleware())
        router.get("/") { _, _ -> HTTPResponseStatus in
            try await Task.sleep(for: .milliseconds(2))
            return .ok
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/", method: .GET) { response in
                XCTAssertEqual(response.status, .ok)
            }
        }

        await self.wait(for: [expectation], timeout: 1)

        XCTAssertEqual(tracer.spans.count, 2)
        let span2 = tracer.spans[1]

        XCTAssertEqual(span2.context.testID, "testMiddleware")
    }
}

#if compiler(>=5.5.2) && canImport(_Concurrency)

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension TracingTests {
    /// Test tracing middleware serviceContext is propagated to async route handlers
    func testServiceContextPropagationAsync() async throws {
        let expectation = expectation(description: "Expected span to be ended.")
        expectation.expectedFulfillmentCount = 2

        let tracer = TestTracer()
        tracer.onEndSpan = { _ in expectation.fulfill() }
        InstrumentationSystem.bootstrapInternal(tracer)

        let router = HBRouterBuilder(context: HBTestRouterContext.self)
        router.middlewares.add(HBTracingMiddleware())
        router.get("/") { _, _ -> HTTPResponseStatus in
            try await Task.sleep(nanoseconds: 1000)
            return InstrumentationSystem.tracer.withAnySpan("testing", ofKind: .server) { _ in
                return .ok
            }
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/", method: .GET) { response in
                XCTAssertEqual(response.status, .ok)
            }
        }

        await self.wait(for: [expectation], timeout: 1)

        XCTAssertEqual(tracer.spans.count, 2)
        let span = tracer.spans[0]
        let span2 = tracer.spans[1]

        XCTAssertEqual(span2.context.traceID, span.context.traceID)
    }
}

#endif // compiler(>=5.5.2) && canImport(_Concurrency)

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

private func XCTAssertSpanAttributesEqual(
    _ lhs: @autoclosure () -> SpanAttributes,
    _ rhs: @autoclosure () -> [String: SpanAttribute],
    file: StaticString = #file,
    line: UInt = #line
) {
    var rhs = rhs()

    lhs().forEach { key, attribute in
        if let rhsValue = rhs.removeValue(forKey: key) {
            if rhsValue != attribute {
                XCTFail(
                    #""\#(key)" was expected to be "\#(rhsValue)" but is actually "\#(attribute)"."#,
                    file: file,
                    line: line
                )
            }
        } else {
            XCTFail(
                #"Did not specify expected value for "\#(key)", actual value is "\#(attribute)"."#,
                file: file,
                line: line
            )
        }
    }

    if !rhs.isEmpty {
        XCTFail(#"Expected attributes "\#(rhs.keys)" are not present in actual attributes."#, file: file, line: line)
    }
}
