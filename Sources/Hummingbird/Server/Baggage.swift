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

import Tracing

extension HBRequest {
    /// Baggage attached to request. Used to propagate baggage to child functions
    public var baggage: Baggage {
        get { self.extensions.get(\.baggage) ?? Baggage.topLevel }
        set { self.extensions.set(\.baggage, value: newValue) }
    }

    /// Execute the given operation with edited request that includes baggage
    ///
    /// - Parameters:
    ///   - baggage: Baggage to attach to request
    ///   - operation: operation to run
    /// - Returns: return value of operation
    public func withBaggage<Return>(_ baggage: Baggage, _ operation: (HBRequest) throws -> Return) rethrows -> Return {
        var request = self
        request.baggage = baggage
        return try operation(request)
    }

    /// Execute the given operation within a newly created ``Span``,
    ///
    /// DO NOT `end()` the passed in span manually. It will be ended automatically when the `operation` returns.
    ///
    /// - Parameters:
    ///   - operationName: The name of the operation being traced. This may be a handler function, database call, ...
    ///   - kind: The ``SpanKind`` of the ``Span`` to be created. Defaults to ``SpanKind/internal``.
    ///   - operation: operation to wrap in a span start/end and execute immediately
    /// - Returns: the value returned by `operation`
    /// - Throws: the error the `operation` has thrown (if any)
    public func withSpan<Return>(
        _ operationName: String,
        ofKind kind: SpanKind = .internal,
        _ operation: (HBRequest, Span) throws -> Return
    ) rethrows -> Return {
        return try self.withSpan(operationName, baggage: self.baggage, ofKind: kind, operation)
    }

    /// Execute a specific task within a newly created ``Span``.
    ///
    /// Calls operation with edited request that includes the baggage, and the span
    /// DO NOT `end()` the passed in span manually. It will be ended automatically when the `operation` returns.
    ///
    /// - Parameters:
    ///   - operationName: The name of the operation being traced. This may be a handler function, database call, ...
    ///   - baggage: Baggage potentially containing trace identifiers of a parent ``Span``.
    ///   - kind: The ``SpanKind`` of the ``Span`` to be created. Defaults to ``SpanKind/internal``.
    ///   - operation: operation to wrap in a span start/end and execute immediately
    /// - Returns: the value returned by `operation`
    /// - Throws: the error the `operation` has thrown (if any)
    public func withSpan<Return>(
        _ operationName: String,
        baggage: Baggage,
        ofKind kind: SpanKind = .internal,
        _ operation: (HBRequest, Span) throws -> Return
    ) rethrows -> Return {
        let span = InstrumentationSystem.tracer.startSpan(operationName, baggage: baggage, ofKind: kind)
        defer { span.end() }
        return try self.withBaggage(span.baggage) { request in
            do {
                return try operation(request, span)
            } catch {
                span.recordError(error)
                throw error
            }
        }
    }

    /// Execute the given operation within a newly created ``Span``,
    ///
    /// DO NOT `end()` the passed in span manually. It will be ended automatically when the `operation` returns.
    ///
    /// - Parameters:
    ///   - operationName: The name of the operation being traced. This may be a handler function, database call, ...
    ///   - kind: The ``SpanKind`` of the ``Span`` to be created. Defaults to ``SpanKind/internal``.
    ///   - operation: operation to wrap in a span start/end and execute immediately
    /// - Returns: the value returned by `operation`
    /// - Throws: the error the `operation` has thrown (if any)
    public func withSpan<Return>(
        _ operationName: String,
        ofKind kind: SpanKind = .internal,
        _ operation: (HBRequest, Span) -> EventLoopFuture<Return>
    ) -> EventLoopFuture<Return> {
        return self.withSpan(operationName, baggage: self.baggage, ofKind: kind, operation)
    }

    /// Execute the given operation within a newly created ``Span``,
    ///
    /// DO NOT `end()` the passed in span manually. It will be ended automatically when the `operation` returns.
    ///
    /// - Parameters:
    ///   - operationName: The name of the operation being traced. This may be a handler function, database call, ...
    ///   - kind: The ``SpanKind`` of the ``Span`` to be created. Defaults to ``SpanKind/internal``.
    ///   - operation: operation to wrap in a span start/end and execute immediately
    /// - Returns: the value returned by `operation`
    /// - Throws: the error the `operation` has thrown (if any)
    public func withSpan<Return>(
        _ operationName: String,
        baggage: Baggage,
        ofKind kind: SpanKind = .internal,
        _ operation: (HBRequest, Span) -> EventLoopFuture<Return>
    ) -> EventLoopFuture<Return> {
        let span = InstrumentationSystem.tracer.startSpan(operationName, baggage: baggage, ofKind: kind)
        return self.withBaggage(span.baggage) { request in
            return operation(request, span)
                .flatMapErrorThrowing { error in
                    span.recordError(error)
                    throw error
                }.always { _ in
                    span.end()
                }
        }
    }
}
