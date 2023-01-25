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
@testable import Instrumentation
import Tracing
import XCTest

final class TracingTests: XCTestCase {
    func testTracingMiddleware() throws {
        let expectation = expectation(description: "Expected span to be ended.")

        let tracer = TestTracer()
        tracer.onEndSpan = { _ in expectation.fulfill() }
        InstrumentationSystem.bootstrapInternal(tracer)

        let app = HBApplication(testing: .embedded)
        app.middleware.add(HBTracingMiddleware())
        app.router.get("users/:id") { _ -> String in
            return "42"
        }
        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(uri: "/users/42", method: .GET) { response in
            XCTAssertEqual(response.status, .ok)
            var responseBody = try XCTUnwrap(response.body)
            XCTAssertEqual(responseBody.readString(length: responseBody.readableBytes), "42")
        }

        waitForExpectations(timeout: 1)

        let span = try XCTUnwrap(tracer.spans.first)

        XCTAssertEqual(span.operationName, "/users/:id")
        XCTAssertEqual(span.kind, .server)
        XCTAssertNil(span.status)
        XCTAssertTrue(span.errors.isEmpty)

        XCTAssertSpanAttributesEqual(span.attributes, [
            "http.method": "GET",
            "http.target": "/users/42",
            "http.status_code": 200,
            "http.response_content_length": 2,
            "net.host.name": "localhost",
            "net.host.port": 0,
            "http.flavor": "1.1",
        ])
    }

    func testTracingMiddlewareServerError() throws {
        let expectation = expectation(description: "Expected span to be ended.")

        let tracer = TestTracer()
        tracer.onEndSpan = { _ in expectation.fulfill() }
        InstrumentationSystem.bootstrapInternal(tracer)

        let app = HBApplication(testing: .embedded)
        app.middleware.add(HBTracingMiddleware())
        app.router.post("users") { _ -> String in
            throw HBHTTPError(.internalServerError)
        }
        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(uri: "/users", method: .POST, body: ByteBuffer(string: "42")) { response in
            XCTAssertEqual(response.status, .internalServerError)
        }

        waitForExpectations(timeout: 1)

        let span = try XCTUnwrap(tracer.spans.first)

        XCTAssertEqual(span.operationName, "/users")
        XCTAssertEqual(span.kind, .server)
        XCTAssertEqual(span.status, .init(code: .error))

        XCTAssertEqual(span.errors.count, 1)
        let error = try XCTUnwrap(span.errors.first as? HBHTTPError, "Recorded unexpected errors: \(span.errors)")
        XCTAssertEqual(error.status, .internalServerError)

        XCTAssertSpanAttributesEqual(span.attributes, [
            "http.method": "POST",
            "http.target": "/users",
            "http.status_code": 500,
            "http.request_content_length": 2,
            "net.host.name": "localhost",
            "net.host.port": 0,
            "http.flavor": "1.1",
        ])
    }

    func testTracingMiddlewareIncludingHeaders() throws {
        let expectation = expectation(description: "Expected span to be ended.")

        let tracer = TestTracer()
        tracer.onEndSpan = { _ in expectation.fulfill() }
        InstrumentationSystem.bootstrapInternal(tracer)

        let app = HBApplication(testing: .embedded)
        app.middleware.add(HBTracingMiddleware(recordingHeaders: [
            "accept", "content-type", "cache-control", "does-not-exist",
        ]))
        app.router.get("users/:id") { _ -> HBResponse in
            var headers = HTTPHeaders()
            headers.add(name: "cache-control", value: "86400")
            headers.add(name: "cache-control", value: "public")
            headers.add(name: "content-type", value: "text/plain")
            return HBResponse(
                status: .ok,
                headers: headers,
                body: .byteBuffer(ByteBuffer(string: "42"))
            )
        }
        try app.XCTStart()
        defer { app.XCTStop() }

        var requestHeaders = HTTPHeaders()
        requestHeaders.add(name: "Accept", value: "text/plain")
        requestHeaders.add(name: "Accept", value: "application/json")
        requestHeaders.add(name: "Cache-Control", value: "no-cache")
        try app.XCTExecute(uri: "/users/42", method: .GET, headers: requestHeaders) { response in
            XCTAssertEqual(response.status, .ok)
            var responseBody = try XCTUnwrap(response.body)
            XCTAssertEqual(responseBody.readString(length: responseBody.readableBytes), "42")
        }

        waitForExpectations(timeout: 1)

        let span = try XCTUnwrap(tracer.spans.first)

        XCTAssertEqual(span.operationName, "/users/:id")
        XCTAssertEqual(span.kind, .server)
        XCTAssertNil(span.status)
        XCTAssertTrue(span.errors.isEmpty)

        XCTAssertSpanAttributesEqual(span.attributes, [
            "http.method": "GET",
            "http.target": "/users/42",
            "http.status_code": 200,
            "http.response_content_length": 2,
            "net.host.name": "localhost",
            "net.host.port": 0,
            "http.flavor": "1.1",
            "http.request.header.accept": .stringArray(["text/plain", "application/json"]),
            "http.request.header.cache_control": "no-cache",
            "http.response.header.content_type": "text/plain",
            "http.response.header.cache_control": .stringArray(["86400", "public"]),
        ])
    }

    func testTracingMiddlewareEmptyResponse() throws {
        let expectation = expectation(description: "Expected span to be ended.")

        let tracer = TestTracer()
        tracer.onEndSpan = { _ in expectation.fulfill() }
        InstrumentationSystem.bootstrapInternal(tracer)

        let app = HBApplication(testing: .embedded)
        app.middleware.add(HBTracingMiddleware())
        app.router.post("/users") { _ -> HTTPResponseStatus in
            return .noContent
        }
        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(uri: "/users", method: .POST) { response in
            XCTAssertEqual(response.status, .noContent)
        }

        waitForExpectations(timeout: 1)

        let span = try XCTUnwrap(tracer.spans.first)

        XCTAssertEqual(span.operationName, "/users")
        XCTAssertEqual(span.kind, .server)
        XCTAssertNil(span.status)
        XCTAssertTrue(span.errors.isEmpty)

        XCTAssertSpanAttributesEqual(span.attributes, [
            "http.method": "POST",
            "http.target": "/users",
            "http.status_code": 204,
            "net.host.name": "localhost",
            "net.host.port": 0,
            "http.flavor": "1.1",
        ])
    }

    func testTracingMiddlewareIndexRoute() throws {
        let expectation = expectation(description: "Expected span to be ended.")

        let tracer = TestTracer()
        tracer.onEndSpan = { _ in expectation.fulfill() }
        InstrumentationSystem.bootstrapInternal(tracer)

        let app = HBApplication(testing: .embedded)
        app.middleware.add(HBTracingMiddleware())
        app.router.get("/") { _ -> HTTPResponseStatus in
            return .ok
        }
        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(uri: "/", method: .GET) { response in
            XCTAssertEqual(response.status, .ok)
        }

        waitForExpectations(timeout: 1)

        let span = try XCTUnwrap(tracer.spans.first)

        XCTAssertEqual(span.operationName, "/")
        XCTAssertEqual(span.kind, .server)
        XCTAssertNil(span.status)
        XCTAssertTrue(span.errors.isEmpty)

        XCTAssertSpanAttributesEqual(span.attributes, [
            "http.method": "GET",
            "http.target": "/",
            "http.status_code": 200,
            "net.host.name": "localhost",
            "net.host.port": 0,
            "http.flavor": "1.1",
        ])
    }

    func testTracingMiddlewareRouteNotFound() throws {
        let expectation = expectation(description: "Expected span to be ended.")

        let tracer = TestTracer()
        tracer.onEndSpan = { _ in expectation.fulfill() }
        InstrumentationSystem.bootstrapInternal(tracer)

        let app = HBApplication(testing: .embedded)
        app.middleware.add(HBTracingMiddleware())
        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(uri: "/", method: .GET) { response in
            XCTAssertEqual(response.status, .notFound)
        }

        waitForExpectations(timeout: 1)

        let span = try XCTUnwrap(tracer.spans.first)

        XCTAssertEqual(span.operationName, "HTTP GET route not found")
        XCTAssertEqual(span.kind, .server)
        XCTAssertNil(span.status)

        XCTAssertEqual(span.errors.count, 1)
        let error = try XCTUnwrap(span.errors.first as? HBHTTPError, "Recorded unexpected errors: \(span.errors)")
        XCTAssertEqual(error.status, .notFound)

        XCTAssertSpanAttributesEqual(span.attributes, [
            "http.method": "GET",
            "http.target": "/",
            "http.status_code": 404,
            "net.host.name": "localhost",
            "net.host.port": 0,
            "http.flavor": "1.1",
        ])
    }

    func testBaggagePropagation() throws {
        let expectation = expectation(description: "Expected span to be ended.")
        expectation.expectedFulfillmentCount = 2

        let tracer = TestTracer()
        tracer.onEndSpan = { _ in expectation.fulfill() }
        InstrumentationSystem.bootstrapInternal(tracer)

        let app = HBApplication(testing: .embedded)
        app.middleware.add(HBTracingMiddleware())
        app.router.get("/") { request -> HTTPResponseStatus in
            var baggage = request.baggage
            baggage[TestIDKey.self] = "test"
            let span = InstrumentationSystem.tracer.startSpan("testing", baggage: baggage, ofKind: .server)
            span.end()
            return .ok
        }
        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(uri: "/", method: .GET) { response in
            XCTAssertEqual(response.status, .ok)
        }

        waitForExpectations(timeout: 1)

        XCTAssertEqual(tracer.spans.count, 2)
        let span = tracer.spans[0]
        let span2 = tracer.spans[1]

        XCTAssertEqual(span2.baggage[TestIDKey.self], "test")
        XCTAssertEqual(span2.baggage.traceID, span.baggage.traceID)
    }

    /// Verify baggage set in trace middleware propagates to routes
    func testBaggagePropagationWithSpan() throws {
        let expectation = expectation(description: "Expected span to be ended.")
        expectation.expectedFulfillmentCount = 2

        let tracer = TestTracer()
        tracer.onEndSpan = { _ in expectation.fulfill() }
        InstrumentationSystem.bootstrapInternal(tracer)

        let app = HBApplication(testing: .embedded)
        app.middleware.add(HBTracingMiddleware())
        app.router.get("/") { request -> HTTPResponseStatus in
            var baggage = request.baggage
            baggage[TestIDKey.self] = "test"
            return request.withSpan("TestSpan", baggage: baggage, ofKind: .client) { _, span in
                span.attributes["test-attribute"] = 42
                return .ok
            }
        }
        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(uri: "/", method: .GET) { response in
            XCTAssertEqual(response.status, .ok)
        }

        waitForExpectations(timeout: 1)

        XCTAssertEqual(tracer.spans.count, 2)
        let span = tracer.spans[0]
        let span2 = tracer.spans[1]

        XCTAssertEqual(span2.baggage[TestIDKey.self], "test")
        XCTAssertEqual(span2.attributes["test-attribute"]?.toSpanAttribute(), 42)
        XCTAssertEqual(span2.baggage.traceID, span.baggage.traceID)
    }

    /// And SpanMiddleware in front of tracing middleware and set baggage value and use
    /// EventLoopFuture version of `request.withSpan` to call next.respond
    func testBaggagePropagationEventLoopFuture() throws {
        let expectation = expectation(description: "Expected span to be ended.")
        expectation.expectedFulfillmentCount = 2

        struct SpanMiddleware: HBMiddleware {
            public func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
                var baggage = request.baggage
                baggage[TestIDKey.self] = "testMiddleware"
                return request.withSpan("TestSpan", baggage: baggage, ofKind: .server) { request, _ in
                    next.respond(to: request)
                }
            }
        }

        let tracer = TestTracer()
        tracer.onEndSpan = { _ in expectation.fulfill() }
        InstrumentationSystem.bootstrapInternal(tracer)

        let app = HBApplication(testing: .live)
        app.middleware.add(SpanMiddleware())
        app.middleware.add(HBTracingMiddleware())
        app.router.get("/") { request -> EventLoopFuture<HTTPResponseStatus> in
            return request.eventLoop.scheduleTask(in: .milliseconds(2)) { return .ok }.futureResult
        }
        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(uri: "/", method: .GET) { response in
            XCTAssertEqual(response.status, .ok)
        }

        waitForExpectations(timeout: 1)

        XCTAssertEqual(tracer.spans.count, 2)
        let span2 = tracer.spans[1]

        XCTAssertEqual(span2.baggage[TestIDKey.self], "testMiddleware")
    }
}

#if compiler(>=5.5.2) && canImport(_Concurrency)

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension TracingTests {
    func testBaggagePropagationAsync() throws {
        let expectation = expectation(description: "Expected span to be ended.")
        expectation.expectedFulfillmentCount = 2

        let tracer = TestTracer()
        tracer.onEndSpan = { _ in expectation.fulfill() }
        InstrumentationSystem.bootstrapInternal(tracer)

        let app = HBApplication(testing: .asyncTest)
        app.middleware.add(HBTracingMiddleware())
        app.router.get("/") { _ -> HTTPResponseStatus in
            try await Task.sleep(nanoseconds: 1000)
            return InstrumentationSystem.tracer.withSpan("testing", ofKind: .server) { _ in
                return .ok
            }
        }
        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(uri: "/", method: .GET) { response in
            XCTAssertEqual(response.status, .ok)
        }

        waitForExpectations(timeout: 10)

        XCTAssertEqual(tracer.spans.count, 2)
        let span = tracer.spans[0]
        let span2 = tracer.spans[1]

        XCTAssertEqual(span2.baggage.traceID, span.baggage.traceID)
    }

    /// Test baggage is propagated to AsyncMiddleware and any baggage added in AsyncMiddleware is
    /// propagated to route code
    func testBaggagePropagationAsyncMiddleware() throws {
        struct AsyncSpanMiddleware: HBAsyncMiddleware {
            public func apply(to request: HBRequest, next: HBResponder) async throws -> HBResponse {
                var baggage = request.baggage
                baggage[TestIDKey.self] = "testAsyncMiddleware"
                return try await InstrumentationSystem.tracer.withSpan("TestSpan", baggage: baggage, ofKind: .server) { _ in
                    try await next.respond(to: request)
                }
            }
        }

        let expectation = expectation(description: "Expected span to be ended.")
        expectation.expectedFulfillmentCount = 3

        let tracer = TestTracer()
        tracer.onEndSpan = { _ in expectation.fulfill() }
        InstrumentationSystem.bootstrapInternal(tracer)

        let app = HBApplication(testing: .asyncTest)
        app.middleware.add(HBTracingMiddleware())
        app.middleware.add(AsyncSpanMiddleware())
        app.router.get("/") { request -> HTTPResponseStatus in
            try await Task.sleep(nanoseconds: 1000)
            return request.withSpan("testing", ofKind: .server) { _, _ in
                return .ok
            }
        }
        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(uri: "/", method: .GET) { response in
            XCTAssertEqual(response.status, .ok)
        }

        waitForExpectations(timeout: 10)

        XCTAssertEqual(tracer.spans.count, 3)
        let span1 = tracer.spans[0]
        let span2 = tracer.spans[1]
        let span3 = tracer.spans[2]

        XCTAssertEqual(span1.baggage.traceID, span2.baggage.traceID)
        XCTAssertEqual(span2.baggage.traceID, span3.baggage.traceID)
        XCTAssertEqual(span2.baggage[TestIDKey.self], "testAsyncMiddleware")
        XCTAssertEqual(span3.baggage[TestIDKey.self], "testAsyncMiddleware")
    }
}

#endif // compiler(>=5.5.2) && canImport(_Concurrency)

internal enum TestIDKey: BaggageKey {
    typealias Value = String
    static var nameOverride: String? { "test-id" }
}

extension Baggage {
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
