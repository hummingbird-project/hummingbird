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

import HummingbirdCore
import NIOCore
import NIOHTTPTypes
import XCTest

final class RequestBodyTests: XCTestCase {
    func testSingleRequestBody() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            let (httpSource, httpStream) = NIOAsyncChannelInboundStream<HTTPRequestPart>.makeTestingStream()
            let httpSourceIterator = httpSource.makeAsyncIterator()
            let requestBody = RequestBody(nioAsyncChannelInbound: .init(iterator: httpSourceIterator))
            group.addTask {
                httpStream.yield(.body(ByteBuffer(string: "hello ")))
                httpStream.yield(.body(ByteBuffer(string: "world")))
                httpStream.yield(.end(nil))
                httpStream.finish()
            }
            group.addTask {
                let buffer = try await requestBody.collect(upTo: .max)
                XCTAssertEqual(String(buffer: buffer), "hello world")
            }
            try await group.waitForAll()
        }
    }

    func testMultipleRequestBodies() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            let (httpSource, httpStream) = NIOAsyncChannelInboundStream<HTTPRequestPart>.makeTestingStream()
            let httpSourceIterator = httpSource.makeAsyncIterator()
            let requestBody = RequestBody(nioAsyncChannelInbound: .init(iterator: httpSourceIterator))
            group.addTask {
                httpStream.yield(.body(ByteBuffer(string: "hello ")))
                httpStream.yield(.body(ByteBuffer(string: "world")))
                httpStream.yield(.end(nil))
                httpStream.yield(.head(.init(method: .get, scheme: nil, authority: nil, path: "/test")))
                httpStream.yield(.end(nil))
                httpStream.finish()
            }
            group.addTask {
                let buffer = try await requestBody.collect(upTo: .max)
                XCTAssertEqual(String(buffer: buffer), "hello world")
            }
            try await group.waitForAll()
        }
    }

    #if compiler(>=6.0)
    func testInboundClosureParsingStream() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            let (httpSource, httpStream) = NIOAsyncChannelInboundStream<HTTPRequestPart>.makeTestingStream()
            let httpSourceIterator = httpSource.makeAsyncIterator()
            let requestBody = RequestBody(nioAsyncChannelInbound: .init(iterator: httpSourceIterator))
            let (stream, cont) = AsyncStream.makeStream(of: Void.self)
            group.addTask {
                httpStream.yield(.body(ByteBuffer(string: "hello ")))
                httpStream.yield(.body(ByteBuffer(string: "world")))
                httpStream.yield(.end(nil))
                httpStream.finish()
            }
            group.addTask {
                try await requestBody.consumeWithInboundCloseHandler { requestBody in
                    let buffer = try await requestBody.collect(upTo: .max)
                    XCTAssertEqual(String(buffer: buffer), "hello world")
                    await stream.first { _ in true }
                } onInboundClosed: {
                    cont.yield()
                }
            }
            try await group.waitForAll()
        }
    }

    func testInboundClosureWithoutParsingStream() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            let (httpSource, httpStream) = NIOAsyncChannelInboundStream<HTTPRequestPart>.makeTestingStream()
            let httpSourceIterator = httpSource.makeAsyncIterator()
            let requestBody = RequestBody(nioAsyncChannelInbound: .init(iterator: httpSourceIterator))
            let (stream, cont) = AsyncStream.makeStream(of: Void.self)
            group.addTask {
                httpStream.yield(.body(ByteBuffer(string: "hello ")))
                httpStream.yield(.body(ByteBuffer(string: "world")))
                httpStream.yield(.end(nil))
                httpStream.finish()
            }
            group.addTask {
                try await requestBody.consumeWithInboundCloseHandler { requestBody in
                    await stream.first { _ in true }
                } onInboundClosed: {
                    cont.yield()
                }
            }
            try await group.waitForAll()
        }
    }

    func testInboundClosureWithStreamError() async throws {
        struct TestError: Error {}
        try await withThrowingTaskGroup(of: Void.self) { group in
            let (httpSource, httpStream) = NIOAsyncChannelInboundStream<HTTPRequestPart>.makeTestingStream()
            let httpSourceIterator = httpSource.makeAsyncIterator()
            let requestBody = RequestBody(nioAsyncChannelInbound: .init(iterator: httpSourceIterator))
            let (stream, cont) = AsyncStream.makeStream(of: Void.self)
            group.addTask {
                httpStream.yield(.body(ByteBuffer(string: "hello ")))
                httpStream.yield(.end(nil))
                httpStream.finish(throwing: TestError())
            }
            group.addTask {
                try await requestBody.consumeWithInboundCloseHandler { requestBody in
                    await stream.first { _ in true }
                } onInboundClosed: {
                    cont.yield()
                }
            }
            try await group.waitForAll()
        }
    }

    func testInboundClosureWithStreamErrorIsPassedOn() async throws {
        struct TestError: Error {}
        try await withThrowingTaskGroup(of: Void.self) { group in
            let (httpSource, httpStream) = NIOAsyncChannelInboundStream<HTTPRequestPart>.makeTestingStream()
            let httpSourceIterator = httpSource.makeAsyncIterator()
            let requestBody = RequestBody(nioAsyncChannelInbound: .init(iterator: httpSourceIterator))
            let (stream, cont) = AsyncStream.makeStream(of: Void.self)
            group.addTask {
                httpStream.yield(.body(ByteBuffer(string: "hello ")))
                httpStream.yield(.body(ByteBuffer(string: "world")))
                httpStream.finish(throwing: TestError())
            }
            group.addTask {
                try await requestBody.consumeWithInboundCloseHandler { requestBody in
                    do {
                        _ = try await requestBody.collect(upTo: .max)
                        XCTFail("Should not get here")
                    } catch is TestError {
                        //
                    }
                    await stream.first { _ in true }
                } onInboundClosed: {
                    cont.yield()
                }
            }
            try await group.waitForAll()
        }
    }
    #endif  // compiler(>=6.0)
}
