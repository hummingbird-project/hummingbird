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

import Foundation
import Hummingbird
import HummingbirdTesting
import Metrics
import NIOConcurrencyHelpers
import Testing

final class TestMetrics: MetricsFactory {
    private let lock = NIOLock()
    private let _counters = NIOLockedValueBox([String: CounterHandler]())
    private let _meters = NIOLockedValueBox([String: MeterHandler]())
    private let _recorders = NIOLockedValueBox([String: RecorderHandler]())
    private let _timers = NIOLockedValueBox([String: TimerHandler]())

    public var counters: [String: CounterHandler] { _counters.withLockedValue { $0 } }
    public var meters: [String: MeterHandler] { _meters.withLockedValue { $0 } }
    public var recorders: [String: RecorderHandler] { _recorders.withLockedValue { $0 } }
    public var timers: [String: TimerHandler] { _timers.withLockedValue { $0 } }

    public func makeCounter(label: String, dimensions: [(String, String)]) -> CounterHandler {
        self._counters.withLockedValue { counters in
            self.make(label: label, dimensions: dimensions, registry: &counters, maker: TestCounter.init)
        }
    }

    public func makeMeter(label: String, dimensions: [(String, String)]) -> MeterHandler {
        self._meters.withLockedValue { counters in
            self.make(label: label, dimensions: dimensions, registry: &counters, maker: TestMeter.init)
        }
    }

    public func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> RecorderHandler {
        let maker = { (label: String, dimensions: [(String, String)]) -> RecorderHandler in
            TestRecorder(label: label, dimensions: dimensions, aggregate: aggregate)
        }
        return self._recorders.withLockedValue { recorders in
            self.make(label: label, dimensions: dimensions, registry: &recorders, maker: maker)
        }
    }

    public func makeTimer(label: String, dimensions: [(String, String)]) -> TimerHandler {
        self._timers.withLockedValue { timers in
            self.make(label: label, dimensions: dimensions, registry: &timers, maker: TestTimer.init)
        }
    }

    private func make<Item>(
        label: String,
        dimensions: [(String, String)],
        registry: inout [String: Item],
        maker: (String, [(String, String)]) -> Item
    ) -> Item {
        let item = maker(label, dimensions)
        registry[label] = item
        return item
    }

    func destroyCounter(_ handler: CounterHandler) {
        if let testCounter = handler as? TestCounter {
            _ = self._counters.withLockedValue { counters in
                counters.removeValue(forKey: testCounter.label)
            }
        }
    }

    func destroyMeter(_ handler: MeterHandler) {
        if let testMeter = handler as? TestMeter {
            _ = self._counters.withLockedValue { counters in
                counters.removeValue(forKey: testMeter.label)
            }
        }
    }

    func destroyRecorder(_ handler: RecorderHandler) {
        if let testRecorder = handler as? TestRecorder {
            _ = self._recorders.withLockedValue { recorders in
                recorders.removeValue(forKey: testRecorder.label)
            }
        }
    }

    func destroyTimer(_ handler: TimerHandler) {
        if let testTimer = handler as? TestTimer {
            _ = self._timers.withLockedValue { timers in
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
        lhs.id == rhs.id
    }
}

internal final class TestMeter: MeterHandler, Equatable {
    let id: String
    let label: String
    let dimensions: [(String, String)]
    let values = NIOLockedValueBox([(Date, Double)]())

    init(label: String, dimensions: [(String, String)]) {
        self.id = NSUUID().uuidString
        self.label = label
        self.dimensions = dimensions
    }

    func set(_ value: Int64) {
        self.set(Double(value))
    }

    func set(_ value: Double) {
        self.values.withLockedValue { values in
            values.append((Date(), value))
        }
        print("adding \(value) to \(self.label)")
    }

    func increment(by: Double) {
        self.values.withLockedValue { values in
            let value = values.last?.1 ?? 0.0
            values.append((Date(), value + by))
        }
        print("incrementing \(by) to \(self.label)")

    }

    func decrement(by: Double) {
        self.values.withLockedValue { values in
            let value = values.last?.1 ?? 0.0
            values.append((Date(), value - by))
        }
        print("decrementing \(by) to \(self.label)")

    }

    static func == (lhs: TestMeter, rhs: TestMeter) -> Bool {
        lhs.id == rhs.id
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
        lhs.id == rhs.id
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
        self.values.withLockedValue { values in
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
        lhs.id == rhs.id
    }
}

final class TaskUniqueTestMetrics: MetricsFactory {
    @TaskLocal static var current: TestMetrics = .init()
    func withUnique<Value: Sendable>(
        _ operation: () async throws -> Value
    ) async throws -> Value {
        try await TaskUniqueTestMetrics.$current.withValue(TestMetrics()) {
            try await operation()
        }
    }

    func makeCounter(label: String, dimensions: [(String, String)]) -> any CoreMetrics.CounterHandler {
        TaskUniqueTestMetrics.current.makeCounter(label: label, dimensions: dimensions)
    }

    public func makeMeter(label: String, dimensions: [(String, String)]) -> MeterHandler {
        TaskUniqueTestMetrics.current.makeMeter(label: label, dimensions: dimensions)
    }

    func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> any CoreMetrics.RecorderHandler {
        TaskUniqueTestMetrics.current.makeRecorder(label: label, dimensions: dimensions, aggregate: aggregate)
    }

    func makeTimer(label: String, dimensions: [(String, String)]) -> any CoreMetrics.TimerHandler {
        TaskUniqueTestMetrics.current.makeTimer(label: label, dimensions: dimensions)
    }

    func destroyCounter(_ handler: any CoreMetrics.CounterHandler) {
        TaskUniqueTestMetrics.current.destroyCounter(handler)
    }

    func destroyMeter(_ handler: MeterHandler) {
        TaskUniqueTestMetrics.current.destroyMeter(handler)
    }

    func destroyRecorder(_ handler: any CoreMetrics.RecorderHandler) {
        TaskUniqueTestMetrics.current.destroyRecorder(handler)
    }

    func destroyTimer(_ handler: any CoreMetrics.TimerHandler) {
        TaskUniqueTestMetrics.current.destroyTimer(handler)
    }

    public var counters: [String: CounterHandler] { TaskUniqueTestMetrics.current.counters }
    public var meters: [String: MeterHandler] { TaskUniqueTestMetrics.current.meters }
    public var recorders: [String: RecorderHandler] { TaskUniqueTestMetrics.current.recorders }
    public var timers: [String: TimerHandler] { TaskUniqueTestMetrics.current.timers }

}

struct MetricsTests {
    static let testMetrics = {
        let metrics = TaskUniqueTestMetrics()
        MetricsSystem.bootstrap(metrics)
        return metrics
    }()

    @Test func testCounter() async throws {
        try await Self.testMetrics.withUnique {
            let router = Router()
            router.middlewares.add(MetricsMiddleware())
            router.get("/hello") { _, _ -> String in
                "Hello"
            }
            let app = Application(responder: router.buildResponder())
            try await app.test(.router) { client in
                try await client.execute(uri: "/hello", method: .get) { _ in }
            }

            let counter = try #require(Self.testMetrics.counters["hb.requests"] as? TestCounter)
            #expect(counter.values.withLockedValue { $0 }[0].1 == 1)
            #expect(counter.dimensions[0].0 == "http.route")
            #expect(counter.dimensions[0].1 == "/hello")
            #expect(counter.dimensions[1].0 == "http.request.method")
            #expect(counter.dimensions[1].1 == "GET")
        }
    }

    @Test func testError() async throws {
        try await Self.testMetrics.withUnique {
            let router = Router()
            router.middlewares.add(MetricsMiddleware())
            router.get("/hello") { _, _ -> String in
                throw HTTPError(.badRequest)
            }
            let app = Application(responder: router.buildResponder())
            try await app.test(.router) { client in
                try await client.execute(uri: "/hello", method: .get) { _ in }
            }

            let counter = try #require(Self.testMetrics.counters["hb.requests"] as? TestCounter)
            #expect(counter.values.withLockedValue { $0 }[0].1 == 1)
            #expect(counter.dimensions[0].0 == "http.route")
            #expect(counter.dimensions[0].1 == "/hello")
            #expect(counter.dimensions[1].0 == "http.request.method")
            #expect(counter.dimensions[1].1 == "GET")
            #expect(counter.dimensions[2].0 == "http.response.status_code")
            #expect(counter.dimensions[2].1 == "400")
            let errorCounter = try #require(Self.testMetrics.counters["hb.request.errors"] as? TestCounter)
            #expect(errorCounter.values.withLockedValue { $0 }.count == 1)
            #expect(errorCounter.values.withLockedValue { $0 }[0].1 == 1)
            #expect(errorCounter.dimensions[0].0 == "http.route")
            #expect(errorCounter.dimensions[0].1 == "/hello")
            #expect(errorCounter.dimensions[1].0 == "http.request.method")
            #expect(errorCounter.dimensions[1].1 == "GET")
        }
    }

    @Test func testNotFoundError() async throws {
        try await Self.testMetrics.withUnique {
            let router = Router()
            router.middlewares.add(MetricsMiddleware())
            router.get("/hello") { _, _ -> String in
                "hello"
            }
            let app = Application(responder: router.buildResponder())
            try await app.test(.router) { client in
                try await client.execute(uri: "/hello2", method: .get) { _ in }
            }

            let counter = try #require(Self.testMetrics.counters["hb.requests"] as? TestCounter)
            #expect(counter.values.withLockedValue { $0 }[0].1 == 1)
            #expect(counter.dimensions[0].0 == "http.route")
            #expect(counter.dimensions[0].1 == "NotFound")
            #expect(counter.dimensions[1].0 == "http.request.method")
            #expect(counter.dimensions[1].1 == "GET")
            #expect(counter.dimensions[2].0 == "http.response.status_code")
            #expect(counter.dimensions[2].1 == "404")
            let errorCounter = try #require(Self.testMetrics.counters["hb.request.errors"] as? TestCounter)
            #expect(errorCounter.values.withLockedValue { $0 }.count == 1)
            #expect(errorCounter.values.withLockedValue { $0 }[0].1 == 1)
            #expect(errorCounter.dimensions.count == 3)
            #expect(errorCounter.dimensions[0].0 == "http.route")
            #expect(errorCounter.dimensions[0].1 == "NotFound")
            #expect(errorCounter.dimensions[1].0 == "http.request.method")
            #expect(errorCounter.dimensions[1].1 == "GET")
            #expect(errorCounter.dimensions[2].0 == "error.type")
            #expect(errorCounter.dimensions[2].1 == "404")
        }
    }

    @Test func testParameterEndpoint() async throws {
        try await Self.testMetrics.withUnique {
            let router = Router()
            router.middlewares.add(MetricsMiddleware())
            router.get("/user/:id") { _, _ -> String in
                throw HTTPError(.badRequest)
            }
            let app = Application(responder: router.buildResponder())
            try await app.test(.router) { client in
                try await client.execute(uri: "/user/765", method: .get) { _ in }
            }

            let counter = try #require(Self.testMetrics.counters["hb.request.errors"] as? TestCounter)
            #expect(counter.values.withLockedValue { $0 }.count == 1)
            #expect(counter.values.withLockedValue { $0 }[0].1 == 1)
            #expect(counter.dimensions.count == 3)
            #expect(counter.dimensions[0].0 == "http.route")
            #expect(counter.dimensions[0].1 == "/user/{id}")
            #expect(counter.dimensions[1].0 == "http.request.method")
            #expect(counter.dimensions[1].1 == "GET")
            #expect(counter.dimensions[2].0 == "error.type")
            #expect(counter.dimensions[2].1 == "400")
        }
    }

    @Test func testRecordingBodyWriteTime() async throws {
        try await Self.testMetrics.withUnique {
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

            let timer = try #require(Self.testMetrics.timers["http.server.request.duration"] as? TestTimer)
            #expect(timer.values.withLockedValue { $0 }[0].1 > 5_000_000)
        }
    }

    @Test func testActiveRequestsMetric() async throws {
        try await Self.testMetrics.withUnique {
            let router = Router()
            router.middlewares.add(MetricsMiddleware())
            router.get("/hello") { _, _ -> Response in
                Response(status: .ok)
            }
            let app = Application(responder: router.buildResponder())
            try await app.test(.router) { client in
                try await client.execute(uri: "/hello", method: .get) { _ in }
            }

            let meter = try #require(Self.testMetrics.meters["http.server.active_requests"] as? TestMeter)
            let values = meter.values.withLockedValue { $0 }.map { $0.1 }
            let maxValue = values.max() ?? 0.0
            #expect(maxValue > 0.0)
        }
    }
}
