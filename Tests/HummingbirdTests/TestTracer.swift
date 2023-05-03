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
//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020-2023 Apple Inc. and the Swift Distributed Tracing project
// authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Dispatch
import Foundation
import Instrumentation
import InstrumentationBaggage
import Tracing

/// Only intended to be used in single-threaded testing.
final class TestTracer: LegacyTracer {
    private(set) var spans = [TestSpan]()
    var onEndSpan: (TestSpan) -> Void = { _ in }

    func startAnySpan<Instant: TracerInstant>(
        _ operationName: String,
        baggage: @autoclosure () -> Baggage,
        ofKind kind: SpanKind,
        at instant: @autoclosure () -> Instant,
        function: String,
        file fileID: String,
        line: UInt
    ) -> any Span {
        let span = TestSpan(
            operationName: operationName,
            at: instant(),
            baggage: baggage(),
            kind: kind,
            onEnd: self.onEndSpan
        )
        self.spans.append(span)
        return span
    }

    public func forceFlush() {}

    func extract<Carrier, Extract>(_ carrier: Carrier, into baggage: inout Baggage, using extractor: Extract)
        where
        Extract: Extractor,
        Carrier == Extract.Carrier
    {
        let traceID = extractor.extract(key: "trace-id", from: carrier) ?? UUID().uuidString
        baggage.traceID = traceID
    }

    func inject<Carrier, Inject>(_ baggage: Baggage, into carrier: inout Carrier, using injector: Inject)
        where
        Inject: Injector,
        Carrier == Inject.Carrier
    {
        guard let traceID = baggage.traceID else { return }
        injector.inject(traceID, forKey: "trace-id", into: &carrier)
    }
}

#if swift(>=5.7.0)
extension TestTracer: Tracer {
    func startSpan<Instant: TracerInstant>(
        _ operationName: String,
        baggage: @autoclosure () -> Baggage,
        ofKind kind: SpanKind,
        at instant: @autoclosure () -> Instant,
        function: String,
        file fileID: String,
        line: UInt
    ) -> TestSpan {
        let span = TestSpan(
            operationName: operationName,
            at: instant(),
            baggage: baggage(),
            kind: kind,
            onEnd: self.onEndSpan
        )
        self.spans.append(span)
        return span
    }
}
#endif

extension TestTracer {
    enum TraceIDKey: BaggageKey {
        typealias Value = String
    }

    enum SpanIDKey: BaggageKey {
        typealias Value = String
    }
}

extension Baggage {
    var traceID: String? {
        get {
            self[TestTracer.TraceIDKey.self]
        }
        set {
            self[TestTracer.TraceIDKey.self] = newValue
        }
    }

    var spanID: String? {
        get {
            self[TestTracer.SpanIDKey.self]
        }
        set {
            self[TestTracer.SpanIDKey.self] = newValue
        }
    }
}

/// Only intended to be used in single-threaded testing.
final class TestSpan: Span {
    public let kind: SpanKind
    public let startTime: UInt64
    public private(set) var status: SpanStatus?
    public private(set) var endTime: UInt64?

    private(set) var recordedErrors: [(Error, SpanAttributes)] = []

    var operationName: String
    let baggage: Baggage

    private(set) var events = [SpanEvent]() {
        didSet {
            self.isRecording = !self.events.isEmpty
        }
    }

    private(set) var links = [SpanLink]()

    var attributes: SpanAttributes = [:] {
        didSet {
            self.isRecording = !self.attributes.isEmpty
        }
    }

    private(set) var isRecording = false

    let onEnd: (TestSpan) -> Void

    init<Instant: TracerInstant>(
        operationName: String,
        at instant: Instant,
        baggage: Baggage,
        kind: SpanKind,
        onEnd: @escaping (TestSpan) -> Void
    ) {
        self.operationName = operationName
        self.startTime = instant.millisecondsSinceEpoch
        self.baggage = baggage
        self.onEnd = onEnd
        self.kind = kind
    }

    func setStatus(_ status: SpanStatus) {
        self.status = status
        self.isRecording = true
    }

    func addLink(_ link: SpanLink) {
        self.links.append(link)
    }

    func addEvent(_ event: SpanEvent) {
        self.events.append(event)
    }

    func recordError<Instant: TracerInstant>(
        _ error: Error,
        attributes: SpanAttributes,
        at instant: @autoclosure () -> Instant
    ) {
        self.recordedErrors.append((error, attributes))
    }

    func end<Instant: TracerInstant>(at instant: @autoclosure () -> Instant) {
        self.endTime = instant().millisecondsSinceEpoch
        self.onEnd(self)
    }
}

extension TestTracer: @unchecked Sendable {} // only intended for single threaded testing
extension TestSpan: @unchecked Sendable {} // only intended for single threaded testing
