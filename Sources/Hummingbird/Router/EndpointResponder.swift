//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import ContainersPreview
import HTTPAPIs
public import HTTPTypes
import HummingbirdCore

/// Stores endpoint responders for each HTTP method
@available(hummingbird 3.0, *)
@usableFromInline
struct EndpointResponders<Context>: Sendable {
    init(path: RouterPath) {
        self.path = path
        self.methods = [:]
    }

    @inlinable
    public func getResponder(for method: __shared HTTPRequest.Method) -> (any HTTPResponder<Context>)? {
        self.methods[method]
    }

    mutating func addResponder(for method: HTTPRequest.Method, responder: any HTTPResponder<Context>) {
        guard self.methods[method] == nil else {
            preconditionFailure("\(method.rawValue) already has a handler")
        }
        self.methods[method] = responder
    }

    mutating func autoGenerateHeadEndpoint() {
        if self.methods[.head] == nil, let get = methods[.get] {
            self.methods[.head] = CallbackResponder { request, writer, context in
                try await get.respond(to: request, writer: HeadResponseWriter(parentWriter: writer), context: context)
            }
        }
    }

    @usableFromInline
    var methods: [HTTPRequest.Method: any HTTPResponder<Context>]

    @usableFromInline
    var path: RouterPath
}

@available(hummingbird 3.0, *)
private struct HeadResponseWriter<Parent: ResponseWriter & ~Copyable>: ResponseWriter, ~Copyable {
    mutating func sendInformational(_ response: HTTPTypes.HTTPResponse) async throws {
        // do nothing
    }

    consuming func send(_ response: HTTPTypes.HTTPResponse) async throws -> HeadResponseBodyAsyncWriter {
        let writer = try await parentWriter.send(response)
        return HeadResponseBodyAsyncWriter(parentWriter: writer)
    }

    consuming func sendAndFinish<Buffer>(_ response: HTTPTypes.HTTPResponse, buffer: inout Buffer, trailer: HTTPTypes.HTTPFields?) async throws
    where Buffer: ContainersPreview.RangeReplaceableContainer, Buffer.Element == UInt8, Buffer: ~Copyable {
        try await parentWriter.sendAndFinish(response)
    }

    let parentWriter: Parent
    struct HeadResponseBodyAsyncWriter: ResponseBodyAsyncWriter, ~Copyable {
        let parentWriter: Parent.Writer

        mutating func write<Buffer>(buffer: inout Buffer) async throws(any Error)
        where Buffer: RangeReplaceableContainer, UInt8 == Buffer.Element, Buffer: ~Copyable, Buffer.Element: ~Copyable {
            // do nothing
        }

        consuming func finish<Buffer>(buffer: inout Buffer, finalElement: consuming HTTPTypes.HTTPFields?) async throws(any Error)
        where Buffer: RangeReplaceableContainer, UInt8 == Buffer.Element, Buffer: ~Copyable, Buffer.Element: ~Copyable {
            try await parentWriter.finish()
        }
    }
}
