//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Tracing open source project
//
// Copyright (c) 2020-2021 Apple Inc. and the Swift Distributed Tracing project
// authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Dispatch
import Foundation
import Instrumentation
import InstrumentationBaggage
import Tracing

final class TestTracer: Tracer {
    private(set) var spans = [TestSpan]()
    var onEndSpan: (Span) -> Void = { _ in }

    func startSpan(
        _ operationName: String,
        baggage: Baggage,
        ofKind kind: SpanKind,
        at time: DispatchWallTime
    ) -> Span {
        let span = TestSpan(
            operationName: operationName,
            startTime: time,
            baggage: baggage,
            kind: kind,
            onEnd: onEndSpan
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

extension TestTracer {
    enum TraceIDKey: BaggageKey {
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
}

final class TestSpan: Span {
    let operationName: String
    let kind: SpanKind

    private(set) var status: SpanStatus?

    private let startTime: DispatchWallTime
    private(set) var endTime: DispatchWallTime?
    private(set) var errors = [Error]()

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

    let onEnd: (Span) -> Void

    init(
        operationName: String,
        startTime: DispatchWallTime,
        baggage: Baggage,
        kind: SpanKind,
        onEnd: @escaping (Span) -> Void
    ) {
        self.operationName = operationName
        self.startTime = startTime
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

    func recordError(_ error: Error) {
        self.errors.append(error)
    }

    func end(at time: DispatchWallTime) {
        self.endTime = time
        self.onEnd(self)
    }
}
