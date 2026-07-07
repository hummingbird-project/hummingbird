//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import Hummingbird
import HummingbirdTesting
import Metrics
import MetricsTestKit
import NIOConcurrencyHelpers
import Testing

struct MetricsTests {
    @Test func testCounter() async throws {
        let metrics = TestMetrics()
        try await withMetricsFactory(metrics) {
            let router = Router()
            router.middlewares.add(MetricsMiddleware())
            router.get("/hello") { _, _ -> String in
                "Hello"
            }
            let app = Application(responder: router.buildResponder())
            try await app.test(.router) { client in
                try await client.execute(uri: "/hello", method: .get) { _ in }
            }
        }
        let counter = try metrics.expectCounter(
            "hb.requests",
            [("http.route", "/hello"), ("http.request.method", "GET"), ("http.response.status_code", "200")]
        )
        #expect(counter.values[0] == 1)
    }

    @Test func testCounter2() async throws {
        let metrics = TestMetrics()
        try await withMetricsFactory(metrics) {
            let router = Router()
            router.middlewares.add(MetricsMiddleware())
            router.get("/hello") { _, _ -> HTTPResponse.Status in
                switch Int.random(in: 0..<4) {
                case 0: HTTPResponse.Status.ok
                case 1: HTTPResponse.Status.badRequest
                case 2: HTTPResponse.Status.forbidden
                default: throw HTTPError(.notFound)
                }
            }
            let app = Application(responder: router.buildResponder())
            try await app.test(.router) { client in
                for _ in 0..<1000 {
                    try await client.execute(uri: "/hello", method: .get) { _ in }
                }
            }
        }
        let counter1 = try metrics.expectCounter(
            "hb.requests",
            [("http.route", "/hello"), ("http.request.method", "GET"), ("http.response.status_code", "200")]
        )
        let counter2 = try metrics.expectCounter(
            "hb.requests",
            [("http.route", "/hello"), ("http.request.method", "GET"), ("http.response.status_code", "400")]
        )
        let counter3 = try metrics.expectCounter(
            "hb.requests",
            [("http.route", "/hello"), ("http.request.method", "GET"), ("http.response.status_code", "403")]
        )
        let counter4 = try metrics.expectCounter(
            "hb.requests",
            [("http.route", "/hello"), ("http.request.method", "GET"), ("http.response.status_code", "404")]
        )
        #expect(counter1.values.count + counter2.values.count + counter3.values.count + counter4.values.count == 1000)
    }

    @Test func testError() async throws {
        let metrics = TestMetrics()
        try await withMetricsFactory(metrics) {
            let router = Router()
            router.middlewares.add(MetricsMiddleware())
            router.get("/hello") { _, _ -> String in
                throw HTTPError(.badRequest)
            }
            let app = Application(responder: router.buildResponder())
            try await app.test(.router) { client in
                try await client.execute(uri: "/hello", method: .get) { _ in }
            }
        }

        let counter = try metrics.expectCounter(
            "hb.requests",
            [("http.route", "/hello"), ("http.request.method", "GET"), ("http.response.status_code", "400")]
        )
        #expect(counter.values[0] == 1)
        let errorCounter = try metrics.expectCounter(
            "hb.request.errors",
            [("http.route", "/hello"), ("http.request.method", "GET"), ("error.type", "400")]
        )
        #expect(errorCounter.values.count == 1)
    }

    @Test func testNotFoundError() async throws {
        let metrics = TestMetrics()
        try await withMetricsFactory(metrics) {
            let router = Router()
            router.middlewares.add(MetricsMiddleware())
            router.get("/hello") { _, _ -> String in
                "hello"
            }
            let app = Application(responder: router.buildResponder())
            try await app.test(.router) { client in
                try await client.execute(uri: "/hello2", method: .get) { _ in }
            }
        }

        let counter = try metrics.expectCounter(
            "hb.requests",
            [("http.route", "NotFound"), ("http.request.method", "GET"), ("http.response.status_code", "404")]
        )
        #expect(counter.values[0] == 1)
        let errorCounter = try metrics.expectCounter(
            "hb.request.errors",
            [("http.route", "NotFound"), ("http.request.method", "GET"), ("error.type", "404")]
        )
        #expect(errorCounter.values.count == 1)
    }

    @Test func testParameterEndpoint() async throws {
        let metrics = TestMetrics()
        try await withMetricsFactory(metrics) {
            let router = Router()
            router.middlewares.add(MetricsMiddleware())
            router.get("/user/:id") { _, _ -> String in
                throw HTTPError(.badRequest)
            }
            let app = Application(responder: router.buildResponder())
            try await app.test(.router) { client in
                try await client.execute(uri: "/user/765", method: .get) { _ in }
            }
        }

        let errorCounter = try metrics.expectCounter(
            "hb.request.errors",
            [("http.route", "/user/{id}"), ("http.request.method", "GET"), ("error.type", "400")]
        )
        #expect(errorCounter.values.count == 1)
    }

    @Test func testRecordingBodyWriteTime() async throws {
        let metrics = TestMetrics()
        try await withMetricsFactory(metrics) {
            let router = Router()
            router.middlewares.add(MetricsMiddleware())
            router.get("/hello") { _, _ -> Response in
                Response(
                    status: .ok,
                    body: .init { _ in
                        try await Task.sleep(for: .milliseconds(5))
                    }
                )
            }
            let app = Application(responder: router.buildResponder())
            try await app.test(.router) { client in
                try await client.execute(uri: "/hello", method: .get) { _ in }
            }
        }

        let timer = try metrics.expectTimer(
            "http.server.request.duration",
            [("http.route", "/hello"), ("http.request.method", "GET"), ("http.response.status_code", "200")]
        )
        #expect(timer.values.count == 1)
        #expect(timer.values[0] > 5_000_000)
    }

    @Test func testActiveRequestsMetric() async throws {
        let metrics = TestMetrics()
        try await withMetricsFactory(metrics) {
            let router = Router()
            router.middlewares.add(MetricsMiddleware())
            router.get("/hello") { _, _ -> Response in
                Response(status: .ok)
            }
            let app = Application(responder: router.buildResponder())
            try await app.test(.router) { client in
                try await client.execute(uri: "/hello", method: .get) { _ in }
            }
        }

        let meter = try metrics.expectMeter("http.server.active_requests", [("http.request.method", "GET")])
        let values = meter.values
        let maxValue = values.max() ?? 0.0
        #expect(maxValue > 0.0)
    }
}
