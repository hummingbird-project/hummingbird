//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import ContainersPreview
public import HTTPAPIs
public import HTTPTypes

/// Box ResponseWriter in a class, to avoid losing it when it is consumed.
///
/// This is useful for situations where responding to the errors a handler throws requires writing
/// a response. If the handler had already starting writing a response then the boxed ResponseWriter
/// will not be available.
/// ```
/// let boxedWriter = BoxedResponseWriter(writer: writer)
/// do {
///     try await next(request, boxedWriter, context)
/// } catch {
///     if let writer = boxedWriter.take() {
///         try await writer.sendAndFinish(.init(status: .badRequest))
///     }
/// }
/// ```
@available(hummingbird 3.0, *)
public final class BoxedResponseWriter<Writer: ResponseWriter & ~Copyable>: ResponseWriter {
    init(writer: consuming Writer) {
        self.writer = consume writer
    }

    @inlinable
    public func sendInformational(_ response: HTTPResponse) async throws {
        guard self.writer != nil else { throw ResponseWriterError.alreadyUsed }
        try await self.writer!.sendInformational(response)
    }

    @inlinable
    public consuming func send(_ response: HTTPResponse) async throws -> AnyResponseBodyAsyncWriter {
        guard let writer = self.writer.take() else { throw ResponseWriterError.alreadyUsed }
        return try await .init(writer.send(response))
    }

    @inlinable
    public consuming func sendAndFinish<Buffer>(_ response: HTTPResponse, buffer: inout Buffer, trailer: HTTPFields?) async throws
    where Buffer: RangeReplaceableContainer, Buffer.Element == UInt8, Buffer: ~Copyable {
        guard let writer = self.writer.take() else { throw ResponseWriterError.alreadyUsed }
        try await writer.sendAndFinish(response, buffer: &buffer, trailer: trailer)
    }

    public consuming func take() -> Writer? {
        self.writer.take()
    }

    public var writer: Writer?
}

public enum ResponseWriterError: Error, CustomStringConvertible {
    case alreadyUsed

    public var description: String {
        switch self {
        case .alreadyUsed:
            "The response writer is no longer available as it has already been used"
        }
    }
}

@available(hummingbird 3.0, *)
extension ResponseWriter where Self: ~Copyable {
    @inlinable
    public consuming func box() -> BoxedResponseWriter<Self> {
        BoxedResponseWriter(writer: self)
    }
}
