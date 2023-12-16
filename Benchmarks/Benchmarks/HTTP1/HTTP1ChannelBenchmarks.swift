//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import HTTPTypes
import NIOHTTPTypes
import Hummingbird
import HummingbirdCore
import Logging
import NIOCore
import NIOEmbedded
import Benchmark

extension Benchmark {
    @discardableResult
    convenience init?(
        name: String,
        configuration: Benchmark.Configuration = Benchmark.defaultConfiguration, 
        write: @escaping @Sendable (Benchmark, NIOAsyncTestingChannel) async throws -> Void,
        responder: @escaping @Sendable (HBRequest, Channel) async throws -> HBResponse
     ) {
        let http1 = HTTP1Channel(responder: responder)
        let channel = NIOAsyncTestingChannel()
        var task: Task<Void, Never>!
        self.init(name, configuration: configuration) { benchmark in
            for _ in benchmark.scaledIterations {
                for _ in 0..<100 {
                    try await write(benchmark, channel)
                    await channel.testingEventLoop.run()
                    // receive response
                    while true {
                        let part = try await channel.waitForOutboundWrite(as: HTTPResponsePart.self)
                        if case .end(nil) = part {
                            break
                        }
                    }
                }
            }
        } setup: {
            let asyncChannel = try await channel.eventLoop.submit {
                try HTTP1Channel.Value(wrappingChannelSynchronously: channel)
            }.get()
            task = Task {
                await http1.handle(value: asyncChannel, logger: Logger(label: "Testing"))
            }
        } teardown: {
            try await channel.close()
            _ = await task.result
        }
    }
}

let benchmarks = {
    let buffer = ByteBufferAllocator().buffer(repeating: 0xff, count: 10000)
    Benchmark(
        name: "GET",
        configuration: .init(warmupIterations: 10)
    ) { benchmark, channel in
        let head = HTTPRequest(method: .get, scheme: "http", authority: "localhost", path: "/")
        try await channel.writeInbound(HTTPRequestPart.head(head))
        try await channel.writeInbound(HTTPRequestPart.end(nil))
    } responder: { request, channel in
        return .init(status: .ok, body: .init(byteBuffer: buffer))
    }

    Benchmark(
        name: "PUT",
        configuration: .init(warmupIterations: 10)
    ) { benchmark, channel in
        let head = HTTPRequest(method: .put, scheme: "http", authority: "localhost", path: "/")
        try await channel.writeInbound(HTTPRequestPart.head(head))
        try await channel.writeInbound(HTTPRequestPart.body(buffer))
        try await channel.writeInbound(HTTPRequestPart.body(buffer))
        try await channel.writeInbound(HTTPRequestPart.end(nil))
    } responder: { request, channel in
        return .init(status: .ok, body: .init(byteBuffer: buffer))
    }

    Benchmark(
        name: "Echo",
        configuration: .init(warmupIterations: 10)
    ) { benchmark, channel in
        let head = HTTPRequest(method: .post, scheme: "http", authority: "localhost", path: "/")
        try await channel.writeInbound(HTTPRequestPart.head(head))
        try await channel.writeInbound(HTTPRequestPart.body(buffer))
        try await channel.writeInbound(HTTPRequestPart.body(buffer))
        try await channel.writeInbound(HTTPRequestPart.end(nil))
    } responder: { request, channel in
        let buffer = try await request.body.collect(upTo: .max)
        return .init(status: .ok, body: .init(byteBuffer: buffer))
    }
}