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

final class MiddlewareTests: XCTestCase {
    func testMiddleware() throws {
        struct TestMiddleware: HBMiddleware {
            func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
                return next.respond(to: request).map { response in
                    var response = response
                    response.headers.replaceOrAdd(name: "middleware", value: "TestMiddleware")
                    return response
                }
            }
        }
        let app = HBApplication(testing: .embedded)
        app.middleware.add(TestMiddleware())
        app.router.get("/hello") { _ -> String in
            return "Hello"
        }
        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(uri: "/hello", method: .GET) { response in
            XCTAssertEqual(response.headers["middleware"].first, "TestMiddleware")
        }
    }

    func testMiddlewareOrder() throws {
        struct TestMiddleware: HBMiddleware {
            let string: String
            func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
                return next.respond(to: request).map { response in
                    var response = response
                    response.headers.add(name: "middleware", value: string)
                    return response
                }
            }
        }
        let app = HBApplication(testing: .embedded)
        app.middleware.add(TestMiddleware(string: "first"))
        app.middleware.add(TestMiddleware(string: "second"))
        app.router.get("/hello") { _ -> String in
            return "Hello"
        }
        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(uri: "/hello", method: .GET) { response in
            // headers come back in opposite order as middleware is applied to responses in that order
            XCTAssertEqual(response.headers["middleware"].first, "second")
            XCTAssertEqual(response.headers["middleware"].last, "first")
        }
    }

    func testMiddlewareRunOnce() throws {
        struct TestMiddleware: HBMiddleware {
            func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
                return next.respond(to: request).map { response in
                    var response = response
                    XCTAssertNil(response.headers["alreadyRun"].first)
                    response.headers.add(name: "alreadyRun", value: "true")
                    return response
                }
            }
        }
        let app = HBApplication(testing: .embedded)
        app.middleware.add(TestMiddleware())
        app.router.get("/hello") { _ -> String in
            return "Hello"
        }
        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(uri: "/hello", method: .GET) { _ in
        }
    }

    func testMiddlewareRunWhenNoRouteFound() throws {
        struct TestMiddleware: HBMiddleware {
            func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
                return next.respond(to: request).flatMapError { error in
                    guard let httpError = error as? HBHTTPError, httpError.status == .notFound else {
                        return request.failure(error)
                    }
                    return request.failure(.notFound, message: "Edited error")
                }
            }
        }
        let app = HBApplication(testing: .embedded)
        app.middleware.add(TestMiddleware())

        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(uri: "/hello", method: .GET) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "Edited error")
            XCTAssertEqual(response.status, .notFound)
        }
    }

    func testEndpointPathInGroup() throws {
        struct TestMiddleware: HBMiddleware {
            func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
                XCTAssertNotNil(request.endpointPath)
                return next.respond(to: request)
            }
        }
        let app = HBApplication(testing: .embedded)
        app.router.group()
            .add(middleware: TestMiddleware())
            .get("test") { _ in return "test" }

        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(uri: "/test", method: .GET) { _ in }
    }

    func testCORSUseOrigin() throws {
        let app = HBApplication(testing: .embedded)
        app.middleware.add(HBCORSMiddleware())
        app.router.get("/hello") { _ -> String in
            return "Hello"
        }
        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(uri: "/hello", method: .GET, headers: ["origin": "foo.com"]) { response in
            // headers come back in opposite order as middleware is applied to responses in that order
            XCTAssertEqual(response.headers["Access-Control-Allow-Origin"].first, "foo.com")
        }
    }

    func testCORSUseAll() throws {
        let app = HBApplication(testing: .embedded)
        app.middleware.add(HBCORSMiddleware(allowOrigin: .all))
        app.router.get("/hello") { _ -> String in
            return "Hello"
        }
        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(uri: "/hello", method: .GET, headers: ["origin": "foo.com"]) { response in
            // headers come back in opposite order as middleware is applied to responses in that order
            XCTAssertEqual(response.headers["Access-Control-Allow-Origin"].first, "*")
        }
    }

    func testCORSOptions() throws {
        let app = HBApplication(testing: .embedded)
        app.middleware.add(HBCORSMiddleware(
            allowOrigin: .all,
            allowHeaders: ["content-type", "authorization"],
            allowMethods: [.GET, .PUT, .DELETE, .OPTIONS],
            allowCredentials: true,
            exposedHeaders: ["content-length"],
            maxAge: .seconds(3600)
        ))
        app.router.get("/hello") { _ -> String in
            return "Hello"
        }
        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(uri: "/hello", method: .OPTIONS, headers: ["origin": "foo.com"]) { response in
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

    func testRouteLoggingMiddleware() throws {
        let app = HBApplication(testing: .embedded)
        app.middleware.add(HBLogRequestsMiddleware(.debug))
        app.router.put("/hello") { request -> EventLoopFuture<String> in
            return request.failure(.badRequest)
        }
        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(uri: "/hello", method: .PUT) { _ in
        }
    }

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

        XCTAssertEqual(span.attributes.count, 7)
        XCTAssertEqual(span.attributes["http.method"]?.toSpanAttribute(), "GET")
        XCTAssertEqual(span.attributes["http.target"]?.toSpanAttribute(), "/users/42")
        XCTAssertEqual(span.attributes["http.status_code"]?.toSpanAttribute(), 200)
        XCTAssertEqual(span.attributes["http.response_content_length"]?.toSpanAttribute(), 2)
        XCTAssertEqual(span.attributes["net.host.name"]?.toSpanAttribute(), "localhost")
        XCTAssertEqual(span.attributes["net.host.port"]?.toSpanAttribute(), 0)
        XCTAssertEqual(span.attributes["http.flavor"]?.toSpanAttribute(), "1.1")

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

        XCTAssertEqual(span.attributes.count, 11)

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

    func testTracingBaggagePropagation() throws {
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
    func testTracingSpanBaggagePropagation() throws {
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
            return request.withSpan("TestSpan", baggage: baggage, ofKind: .client) { request, span in
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
    func testSpanBaggageEventLoopFuturePropagation() throws {
        let expectation = expectation(description: "Expected span to be ended.")
        expectation.expectedFulfillmentCount = 2

        struct SpanMiddleware: HBMiddleware {
            public func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
                var baggage = request.baggage
                baggage[TestIDKey.self] = "testMiddleware"
                return request.withSpan("TestSpan", baggage: baggage, ofKind: .server) { request, span in
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
            return request.eventLoop.scheduleTask(in: .milliseconds(100)) { return .ok }.futureResult
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
