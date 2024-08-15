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
import HummingbirdTesting
@preconcurrency import Metrics
import NIOConcurrencyHelpers
import XCTest

final class TestMetrics: MetricsFactory {
    private let lock = NIOLock()
    let counters = NIOLockedValueBox([String: CounterHandler]())
    let recorders = NIOLockedValueBox([String: RecorderHandler]())
    let timers = NIOLockedValueBox([String: TimerHandler]())

    public func makeCounter(label: String, dimensions: [(String, String)]) -> CounterHandler {
        self.counters.withLockedValue { counters in
            return self.make(label: label, dimensions: dimensions, registry: &counters, maker: TestCounter.init)
        }
    }

    public func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> RecorderHandler {
        let maker = { (label: String, dimensions: [(String, String)]) -> RecorderHandler in
            TestRecorder(label: label, dimensions: dimensions, aggregate: aggregate)
        }
        return self.recorders.withLockedValue { recorders in
            self.make(label: label, dimensions: dimensions, registry: &recorders, maker: maker)
        }
    }

    public func makeTimer(label: String, dimensions: [(String, String)]) -> TimerHandler {
        self.timers.withLockedValue { timers in
            self.make(label: label, dimensions: dimensions, registry: &timers, maker: TestTimer.init)
        }
    }

    private func make<Item>(label: String, dimensions: [(String, String)], registry: inout [String: Item], maker: (String, [(String, String)]) -> Item) -> Item {
        let item = maker(label, dimensions)
        registry[label] = item
        return item
    }

    func destroyCounter(_ handler: CounterHandler) {
        if let testCounter = handler as? TestCounter {
            _ = self.counters.withLockedValue { counters in
                counters.removeValue(forKey: testCounter.label)
            }
        }
    }

    func destroyRecorder(_ handler: RecorderHandler) {
        if let testRecorder = handler as? TestRecorder {
            _ = self.recorders.withLockedValue { recorders in
                recorders.removeValue(forKey: testRecorder.label)
            }
        }
    }

    func destroyTimer(_ handler: TimerHandler) {
        if let testTimer = handler as? TestTimer {
            _ = self.timers.withLockedValue { timers in
                timers.removeValue(forKey: testTimer.label)
            }
        }
    }
}

internal final class TestCounter: CounterHandler, Equatable {
    let id: String
    let label: String
    let dimensions: [(String, String)]
    let values = NIOLockedValueBox([(Date, Int64)]())

    init(label: String, dimensions: [(String, String)]) {
        self.id = NSUUID().uuidString
        self.label = label
        self.dimensions = dimensions
    }

    func increment(by amount: Int64) {
        self.values.withLockedValue { values in
            values.append((Date(), amount))
        }
        print("adding \(amount) to \(self.label)")
    }

    func reset() {
        self.values.withLockedValue { values in
            values = []
        }
        print("reseting \(self.label)")
    }

    public static func == (lhs: TestCounter, rhs: TestCounter) -> Bool {
        return lhs.id == rhs.id
    }
}

internal final class TestRecorder: RecorderHandler, Equatable {
    let id: String
    let label: String
    let dimensions: [(String, String)]
    let aggregate: Bool
    let values = NIOLockedValueBox([(Date, Double)]())

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
        self.values.withLockedValue { values in
            // this may loose precision but good enough as an example
            values.append((Date(), Double(value)))
        }
        print("recording \(value) in \(self.label)")
    }

    public static func == (lhs: TestRecorder, rhs: TestRecorder) -> Bool {
        return lhs.id == rhs.id
    }
}

internal final class TestTimer: TimerHandler, Equatable {
    let id: String
    let label: String
    let displayUnit: NIOLockedValueBox<TimeUnit?>
    let dimensions: [(String, String)]
    let values = NIOLockedValueBox([(Date, Int64)]())

    init(label: String, dimensions: [(String, String)]) {
        self.id = NSUUID().uuidString
        self.label = label
        self.displayUnit = .init(nil)
        self.dimensions = dimensions
    }

    func preferDisplayUnit(_ unit: TimeUnit) {
        self.displayUnit.withLockedValue { displayUnit in
            displayUnit = unit
        }
    }

    func retriveValueInPreferredUnit(atIndex i: Int) -> Double {
        return self.values.withLockedValue { values in
            let value = values[i].1
            return self.displayUnit.withLockedValue { displayUnit in
                guard let displayUnit else {
                    return Double(value)
                }
                return Double(value) / Double(displayUnit.scaleFromNanoseconds)
            }
        }
    }

    func recordNanoseconds(_ duration: Int64) {
        self.values.withLockedValue { values in
            values.append((Date(), duration))
        }
        print("recording \(duration) \(self.label)")
    }

    public static func == (lhs: TestTimer, rhs: TestTimer) -> Bool {
        return lhs.id == rhs.id
    }
}

final class MetricsTests: XCTestCase {
    static let testMetrics = TestMetrics()

    override class func setUp() {
        MetricsSystem.bootstrap(self.testMetrics)
    }

    func testCounter() async throws {
        let router = Router()
        router.middlewares.add(MetricsMiddleware())
        router.get("/hello") { _, _ -> String in
            return "Hello"
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/hello", method: .get) { _ in }
        }

        let counter = try XCTUnwrap(Self.testMetrics.counters.withLockedValue { $0 }["hb_requests"] as? TestCounter)
        XCTAssertEqual(counter.values.withLockedValue { $0 }[0].1, 1)
        XCTAssertEqual(counter.dimensions[0].0, "hb_uri")
        XCTAssertEqual(counter.dimensions[0].1, "/hello")
        XCTAssertEqual(counter.dimensions[1].0, "hb_method")
        XCTAssertEqual(counter.dimensions[1].1, "GET")
    }

    func testError() async throws {
        let router = Router()
        router.middlewares.add(MetricsMiddleware())
        router.get("/hello") { _, _ -> String in
            throw HTTPError(.badRequest)
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/hello", method: .get) { _ in }
        }

        let counter = try XCTUnwrap(Self.testMetrics.counters.withLockedValue { $0 }["hb_errors"] as? TestCounter)
        XCTAssertEqual(counter.values.withLockedValue { $0 }.count, 1)
        XCTAssertEqual(counter.values.withLockedValue { $0 }[0].1, 1)
        XCTAssertEqual(counter.dimensions[0].0, "hb_uri")
        XCTAssertEqual(counter.dimensions[0].1, "/hello")
        XCTAssertEqual(counter.dimensions[1].0, "hb_method")
        XCTAssertEqual(counter.dimensions[1].1, "GET")
    }

    func testNotFoundError() async throws {
        let router = Router()
        router.middlewares.add(MetricsMiddleware())
        router.get("/hello") { _, _ -> String in
            return "hello"
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/hello2", method: .get) { _ in }
        }

        let counter = try XCTUnwrap(Self.testMetrics.counters.withLockedValue { $0 }["hb_errors"] as? TestCounter)
        XCTAssertEqual(counter.values.withLockedValue { $0 }.count, 1)
        XCTAssertEqual(counter.values.withLockedValue { $0 }[0].1, 1)
        XCTAssertEqual(counter.dimensions.count, 2)
        XCTAssertEqual(counter.dimensions[0].0, "hb_uri")
        XCTAssertEqual(counter.dimensions[0].1, "NotFound")
        XCTAssertEqual(counter.dimensions[1].0, "hb_method")
        XCTAssertEqual(counter.dimensions[1].1, "GET")
    }

    func testParameterEndpoint() async throws {
        let router = Router()
        router.middlewares.add(MetricsMiddleware())
        router.get("/user/:id") { _, _ -> String in
            throw HTTPError(.badRequest)
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/user/765", method: .get) { _ in }
        }

        let counter = try XCTUnwrap(Self.testMetrics.counters.withLockedValue { $0 }["hb_errors"] as? TestCounter)
        XCTAssertEqual(counter.values.withLockedValue { $0 }.count, 1)
        XCTAssertEqual(counter.values.withLockedValue { $0 }[0].1, 1)
        XCTAssertEqual(counter.dimensions.count, 2)
        XCTAssertEqual(counter.dimensions[0].0, "hb_uri")
        XCTAssertEqual(counter.dimensions[0].1, "/user/{id}")
        XCTAssertEqual(counter.dimensions[1].0, "hb_method")
        XCTAssertEqual(counter.dimensions[1].1, "GET")
    }

    func testRecordingBodyWriteTime() async throws {
        let router = Router()
        router.middlewares.add(MetricsMiddleware())
        router.get("/hello") { _, _ -> Response in
            return Response(status: .ok, body: .init { _ in
                try await Task.sleep(for: .milliseconds(5))
            })
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/hello", method: .get) { _ in }
        }

        let timer = try XCTUnwrap(Self.testMetrics.timers.withLockedValue { $0 }["hb_request_duration"] as? TestTimer)
        XCTAssertGreaterThan(timer.values.withLockedValue { $0 }[0].1, 5_000_000)
    }
}
