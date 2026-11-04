//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//
import HTTPTypes
import HummingbirdCore
import NIOCore
import NIOHTTPTypes
import Testing

struct RequestBodyTests {
    @Test func testSingleRequestBody() async throws {
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
                #expect(String(buffer: buffer) == "hello world")
            }
            try await group.waitForAll()
        }
    }

    @Test func testMultipleRequestBodies() async throws {
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
                #expect(String(buffer: buffer) == "hello world")
            }
            try await group.waitForAll()
        }
    }

    /// `Source.yield` used to lose a wakeup when the consumer drained the buffer between the
    /// sequence answering `.stopProducing` and the delegate being told to stop: the producer then
    /// waited for a `produceMore` that never came, and the consumer waited for data forever.
    @Test(.timeLimit(.minutes(1)))
    func testStreamedRequestBodyNeverStallsUnderBackPressure() async throws {
        for _ in 0..<2000 {
            let (requestBody, source) = RequestBody.makeStream()
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    for _ in 0..<64 {
                        await source.yield(ByteBuffer(repeating: 0, count: 16))
                    }
                    source.finish()
                }
                group.addTask {
                    let buffer = try await requestBody.collect(upTo: .max)
                    #expect(buffer.readableBytes == 64 * 16)
                }
                try await group.waitForAll()
            }
        }
    }

    @Test func testInboundClosureParsingStream() async throws {
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
                    #expect(String(buffer: buffer) == "hello world")
                    await stream.first { _ in true }
                } onInboundClosed: {
                    cont.yield()
                }
            }
            try await group.waitForAll()
        }
    }

    @Test func testInboundClosureWithoutParsingStream() async throws {
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

    @Test func testInboundClosureWithStreamError() async throws {
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

    @Test func testInboundClosureWithStreamErrorIsPassedOn() async throws {
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
                    await #expect(throws: TestError.self) {
                        try await requestBody.collect(upTo: .max)
                    }
                    await stream.first { _ in true }
                } onInboundClosed: {
                    cont.yield()
                }
            }
            try await group.waitForAll()
        }
    }
}
