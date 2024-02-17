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
import ServiceContextModule
import Tracing

/// Only intended to be used in single-threaded testing.
final class TestTracer: Tracer {
    private(set) var spans = [TestSpan]()
    var onEndSpan: (TestSpan) -> Void = { _ in }

    func startSpan(
        _ operationName: String,
        context: @autoclosure () -> ServiceContext,
        ofKind kind: SpanKind,
        at instant: @autoclosure () -> some TracerInstant,
        function: String,
        file fileID: String,
        line: UInt
    ) -> TestSpan {
        let span = TestSpan(
            operationName: operationName,
            at: instant(),
            context: context(),
            kind: kind,
            onEnd: self.onEndSpan
        )
        self.spans.append(span)
        return span
    }

    public func forceFlush() {}

    func extract<Carrier, Extract>(_ carrier: Carrier, into context: inout ServiceContext, using extractor: Extract)
        where
        Extract: Extractor,
        Carrier == Extract.Carrier
    {
        let traceID = extractor.extract(key: "trace-id", from: carrier) ?? UUID().uuidString
        context.traceID = traceID
    }

    func inject<Carrier, Inject>(_ context: ServiceContext, into carrier: inout Carrier, using injector: Inject)
        where
        Inject: Injector,
        Carrier == Inject.Carrier
    {
        guard let traceID = context.traceID else { return }
        injector.inject(traceID, forKey: "trace-id", into: &carrier)
    }
}

extension TestTracer {
    enum TraceIDKey: ServiceContextKey {
        typealias Value = String
    }

    enum SpanIDKey: ServiceContextKey {
        typealias Value = String
    }
}

extension ServiceContext {
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
    let context: ServiceContext

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

    init(
        operationName: String,
        at instant: some TracerInstant,
        context: ServiceContext,
        kind: SpanKind,
        onEnd: @escaping (TestSpan) -> Void
    ) {
        self.operationName = operationName
        self.startTime = instant.millisecondsSinceEpoch
        self.context = context
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

    func recordError(
        _ error: Error,
        attributes: SpanAttributes,
        at instant: @autoclosure () -> some TracerInstant
    ) {
        self.recordedErrors.append((error, attributes))
    }

    func end(at instant: @autoclosure () -> some TracerInstant) {
        self.endTime = instant().millisecondsSinceEpoch
        self.onEnd(self)
    }
}

extension TestTracer: @unchecked Sendable {} // only intended for single threaded testing
extension TestSpan: @unchecked Sendable {} // only intended for single threaded testing
