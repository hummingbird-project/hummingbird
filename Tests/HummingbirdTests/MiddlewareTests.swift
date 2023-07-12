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
/*
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
                     response.headers.add(name: "middleware", value: self.string)
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
 }
 */
