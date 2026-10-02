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

@available(hummingbird 3.0, *)
public struct EditHeaderResponseWriter<Sender: ResponseWriter & ~Copyable>: ResponseWriter, ~Copyable {
    @inlinable
    package init(_ sender: consuming Sender, _ edit: @escaping (inout HTTPResponse) async throws -> Void) {
        self.sender = consume sender
        self.edit = edit
    }

    @inlinable
    public mutating func sendInformational(_ response: HTTPResponse) async throws {
        try await self.sender.sendInformational(response)
    }

    @inlinable
    public consuming func send(_ response: HTTPResponse) async throws -> Sender.Writer {
        var response = response
        try await edit(&response)
        return try await self.sender.send(response)
    }

    @inlinable
    public consuming func sendAndFinish<Buffer>(_ response: HTTPResponse, buffer: inout Buffer, trailer: HTTPFields?) async throws
    where Buffer: RangeReplaceableContainer, Buffer.Element == UInt8, Buffer: ~Copyable {
        var response = response
        try await edit(&response)
        return try await self.sender.sendAndFinish(response, buffer: &buffer, trailer: trailer)
    }

    @usableFromInline
    var sender: Sender
    @usableFromInline
    let edit: (inout HTTPResponse) async throws -> Void
}
