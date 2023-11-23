//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
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
import Metrics
import NIOConcurrencyHelpers
import XCTest
/*
final class TestMetrics: MetricsFactory {
    private let lock = NIOLock()
    var counters = [String: CounterHandler]()
    var recorders = [String: RecorderHandler]()
    var timers = [String: TimerHandler]()

    public func makeCounter(label: String, dimensions: [(String, String)]) -> CounterHandler {
        return self.make(label: label, dimensions: dimensions, registry: &self.counters, maker: TestCounter.init)
    }

    public func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> RecorderHandler {
        let maker = { (label: String, dimensions: [(String, String)]) -> RecorderHandler in
            TestRecorder(label: label, dimensions: dimensions, aggregate: aggregate)
        }
        return self.make(label: label, dimensions: dimensions, registry: &self.recorders, maker: maker)
    }

    public func makeTimer(label: String, dimensions: [(String, String)]) -> TimerHandler {
        return self.make(label: label, dimensions: dimensions, registry: &self.timers, maker: TestTimer.init)
    }

    private func make<Item>(label: String, dimensions: [(String, String)], registry: inout [String: Item], maker: (String, [(String, String)]) -> Item) -> Item {
        return self.lock.withLock {
            let item = maker(label, dimensions)
            registry[label] = item
            return item
        }
    }

    func destroyCounter(_ handler: CounterHandler) {
        if let testCounter = handler as? TestCounter {
            self.counters.removeValue(forKey: testCounter.label)
        }
    }

    func destroyRecorder(_ handler: RecorderHandler) {
        if let testRecorder = handler as? TestRecorder {
            self.recorders.removeValue(forKey: testRecorder.label)
        }
    }

    func destroyTimer(_ handler: TimerHandler) {
        if let testTimer = handler as? TestTimer {
            self.timers.removeValue(forKey: testTimer.label)
        }
    }
}

internal class TestCounter: CounterHandler, Equatable {
    let id: String
    let label: String
    let dimensions: [(String, String)]

    let lock = NIOLock()
    var values = [(Date, Int64)]()

    init(label: String, dimensions: [(String, String)]) {
        self.id = NSUUID().uuidString
        self.label = label
        self.dimensions = dimensions
    }

    func increment(by amount: Int64) {
        self.lock.withLock {
            self.values.append((Date(), amount))
        }
        print("adding \(amount) to \(self.label)")
    }

    func reset() {
        self.lock.withLock {
            self.values = []
        }
        print("reseting \(self.label)")
    }

    public static func == (lhs: TestCounter, rhs: TestCounter) -> Bool {
        return lhs.id == rhs.id
    }
}

internal class TestRecorder: RecorderHandler, Equatable {
    let id: String
    let label: String
    let dimensions: [(String, String)]
    let aggregate: Bool

    let lock = NIOLock()
    var values = [(Date, Double)]()

    init(label: String, dimensions: [(String, String)], aggregate: Bool) {
        self.id = NSUUID().uuidString
        self.label = label
        self.dimensions = dimensions
        self.aggregate = aggregate
    }

    func record(_ value: Int64) {
        self.record(Double(value))
    }

    func record(_ value: Double) {
        self.lock.withLock {
            // this may loose precision but good enough as an example
            self.values.append((Date(), Double(value)))
        }
        print("recording \(value) in \(self.label)")
    }

    public static func == (lhs: TestRecorder, rhs: TestRecorder) -> Bool {
        return lhs.id == rhs.id
    }
}

internal class TestTimer: TimerHandler, Equatable {
    let id: String
    let label: String
    var displayUnit: TimeUnit?
    let dimensions: [(String, String)]

    let lock = NIOLock()
    var values = [(Date, Int64)]()

    init(label: String, dimensions: [(String, String)]) {
        self.id = NSUUID().uuidString
        self.label = label
        self.displayUnit = nil
        self.dimensions = dimensions
    }

    func preferDisplayUnit(_ unit: TimeUnit) {
        self.lock.withLock {
            self.displayUnit = unit
        }
    }

    func retriveValueInPreferredUnit(atIndex i: Int) -> Double {
        return self.lock.withLock {
            let value = self.values[i].1
            guard let displayUnit = self.displayUnit else {
                return Double(value)
            }
            return Double(value) / Double(displayUnit.scaleFromNanoseconds)
        }
    }

    func recordNanoseconds(_ duration: Int64) {
        self.lock.withLock {
            self.values.append((Date(), duration))
        }
        print("recording \(duration) \(self.label)")
    }

    public static func == (lhs: TestTimer, rhs: TestTimer) -> Bool {
        return lhs.id == rhs.id
    }
}

final class MetricsTests: XCTestCase {
    static var testMetrics = TestMetrics()

    override class func setUp() {
        MetricsSystem.bootstrap(self.testMetrics)
    }

    func testCounter() async throws {
        let router = HBRouterBuilder(context: HBTestRouterContext.self)
        router.middlewares.add(HBMetricsMiddleware())
        router.get("/hello") { _, _ -> String in
            return "Hello"
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/hello", method: .GET) { _ in }
        }

        let counter = try XCTUnwrap(Self.testMetrics.counters["hb_requests"] as? TestCounter)
        XCTAssertEqual(counter.values[0].1, 1)
        XCTAssertEqual(counter.dimensions[0].0, "hb_uri")
        XCTAssertEqual(counter.dimensions[0].1, "/hello")
        XCTAssertEqual(counter.dimensions[1].0, "hb_method")
        XCTAssertEqual(counter.dimensions[1].1, "GET")
    }

    func testError() async throws {
        let router = HBRouterBuilder(context: HBTestRouterContext.self)
        router.middlewares.add(HBMetricsMiddleware())
        router.get("/hello") { _, _ -> String in
            throw HBHTTPError(.badRequest)
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/hello", method: .GET) { _ in }
        }

        let counter = try XCTUnwrap(Self.testMetrics.counters["hb_errors"] as? TestCounter)
        XCTAssertEqual(counter.values.count, 1)
        XCTAssertEqual(counter.values[0].1, 1)
        XCTAssertEqual(counter.dimensions[0].0, "hb_uri")
        XCTAssertEqual(counter.dimensions[0].1, "/hello")
        XCTAssertEqual(counter.dimensions[1].0, "hb_method")
        XCTAssertEqual(counter.dimensions[1].1, "GET")
    }

    func testNotFoundError() async throws {
        let router = HBRouterBuilder(context: HBTestRouterContext.self)
        router.middlewares.add(HBMetricsMiddleware())
        router.get("/hello") { _, _ -> String in
            return "hello"
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/hello2", method: .GET) { _ in }
        }

        let counter = try XCTUnwrap(Self.testMetrics.counters["hb_errors"] as? TestCounter)
        XCTAssertEqual(counter.values.count, 1)
        XCTAssertEqual(counter.values[0].1, 1)
        XCTAssertEqual(counter.dimensions.count, 1)
        XCTAssertEqual(counter.dimensions[0].0, "hb_method")
        XCTAssertEqual(counter.dimensions[0].1, "GET")
    }

    func testParameterEndpoint() async throws {
        let router = HBRouterBuilder(context: HBTestRouterContext.self)
        router.middlewares.add(HBMetricsMiddleware())
        router.get("/user/:id") { _, _ -> String in
            throw HBHTTPError(.badRequest)
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/user/765", method: .GET) { _ in }
        }

        let counter = try XCTUnwrap(Self.testMetrics.counters["hb_errors"] as? TestCounter)
        XCTAssertEqual(counter.values.count, 1)
        XCTAssertEqual(counter.values[0].1, 1)
        XCTAssertEqual(counter.dimensions.count, 2)
        XCTAssertEqual(counter.dimensions[0].0, "hb_uri")
        XCTAssertEqual(counter.dimensions[0].1, "/user/:id")
        XCTAssertEqual(counter.dimensions[1].0, "hb_method")
        XCTAssertEqual(counter.dimensions[1].1, "GET")
    }
}
*/