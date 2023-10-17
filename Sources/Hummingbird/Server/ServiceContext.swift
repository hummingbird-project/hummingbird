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

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension HBRequestContext {
    /// ServiceContext attached to request. Used to propagate serviceContext to child functions
    ///
    /// Attaching serviceContext to the request should be used when we aren't inside an async
    /// function and serviceContext cannot be propagated via Task local variables. Otherwise
    /// serviceContext should be propagated using Task local variables using `ServiceContext.$current.withValue(_)`
    public var serviceContext: ServiceContext {
        get { self.extensions.get(\.serviceContext) ?? ServiceContext.topLevel }
        set { self.extensions.set(\.serviceContext, value: newValue) }
    }

    /// Execute the given operation with edited request that includes serviceContext.
    ///
    /// Be sure to use the ``HBRequest`` passed to the closure as that includes the serviceContext.
    /// This function should be used when we aren't inside an async function and serviceContext
    /// cannot be propagated via Task local variables using `ServiceContext.$current.withValue(_)`
    ///
    /// - Parameters:
    ///   - serviceContext: ServiceContext to attach to request
    ///   - operation: operation to run
    /// - Returns: return value of operation
    public func withServiceContext<Return>(_ serviceContext: ServiceContext, _ operation: (HBRequestContext) throws -> Return) rethrows -> Return {
        var context = self
        context.serviceContext = serviceContext
        return try operation(context)
    }

    /// Execute the given operation within a newly created ``Span``
    ///
    /// Calls operation with edited request that includes the serviceContext from span, and the span Be sure to use the
    /// `HBRequest` passed to the closure as that includes the serviceContext
    ///
    /// This function should be used when we aren't inside an async function and serviceContext cannot be propagated
    /// via Task local variables. The equivalent async version of this is
    /// `InstrumentationSystem.tracer.withSpan(_:ofKind:_)`
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
        _ operation: (HBRequestContext, Span) throws -> Return
    ) rethrows -> Return {
        return try self.withSpan(operationName, serviceContext: self.serviceContext, ofKind: kind, operation)
    }

    /// Execute a specific task within a newly created ``Span``.
    ///
    /// Calls operation with edited request that includes the serviceContext, and the span Be sure to use the
    /// `HBRequest` passed to the closure as that includes the serviceContext
    ///
    /// This function should be used when we aren't inside an async function and serviceContext cannot be propagated
    /// via Task local variables. The equivalent async version of this is
    /// `InstrumentationSystem.tracer.withSpan(_:serviceContext:ofKind:_)`
    ///
    /// DO NOT `end()` the passed in span manually. It will be ended automatically when the `operation` returns.
    ///
    /// - Parameters:
    ///   - operationName: The name of the operation being traced. This may be a handler function, database call, ...
    ///   - serviceContext: ServiceContext potentially containing trace identifiers of a parent ``Span``.
    ///   - kind: The ``SpanKind`` of the ``Span`` to be created. Defaults to ``SpanKind/internal``.
    ///   - operation: operation to wrap in a span start/end and execute immediately
    /// - Returns: the value returned by `operation`
    /// - Throws: the error the `operation` has thrown (if any)
    public func withSpan<Return>(
        _ operationName: String,
        serviceContext: ServiceContext,
        ofKind kind: SpanKind = .internal,
        _ operation: (HBRequestContext, Span) throws -> Return
    ) rethrows -> Return {
        let span = InstrumentationSystem.legacyTracer.startAnySpan(operationName, context: serviceContext, ofKind: kind)
        defer { span.end() }
        return try self.withServiceContext(span.context) { request in
            do {
                return try operation(request, span)
            } catch {
                span.recordError(error)
                throw error
            }
        }
    }

    /// Execute the given operation within a newly created ``Span``
    ///
    /// Calls operation with edited request that includes the serviceContext from span, and the span. Be sure to use the
    /// `HBRequest` passed to the closure as that includes the serviceContext
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
        _ operation: (HBRequestContext, Span) -> EventLoopFuture<Return>
    ) -> EventLoopFuture<Return> {
        return self.withSpan(operationName, serviceContext: self.serviceContext, ofKind: kind, operation)
    }

    /// Execute the given operation within a newly created ``Span``,
    ///
    /// Calls operation with edited request that includes the serviceContext, and the span. Be sure to use the
    /// `HBRequest` passed to the closure as that includes the serviceContext
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
        serviceContext: ServiceContext,
        ofKind kind: SpanKind = .internal,
        _ operation: (HBRequestContext, Span) -> EventLoopFuture<Return>
    ) -> EventLoopFuture<Return> {
        let span = InstrumentationSystem.legacyTracer.startAnySpan(operationName, context: serviceContext, ofKind: kind)
        return self.withServiceContext(span.context) { context in
            return operation(context, span)
                .flatMapErrorThrowing { error in
                    span.recordError(error)
                    throw error
                }.always { _ in
                    span.end()
                }
        }
    }
}
