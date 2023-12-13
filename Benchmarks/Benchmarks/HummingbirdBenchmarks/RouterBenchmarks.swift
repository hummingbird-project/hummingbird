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
@_spi(HBXCT) import HummingbirdCore
import Logging
import Benchmark
import NIOCore
import NIOPosix

/// Implementation of a basic request context that supports everything the Hummingbird library needs
protocol BenchmarkContext: HBBaseRequestContext {
    ///  Initialize an `HBRequestContext`
    /// - Parameters:
    ///   - applicationContext: Context from Application that instigated the request
    ///   - source: Source of request context
    ///   - logger: Logger
    init(
        applicationContext: HBApplicationContext,
        eventLoop: EventLoop,
        allocator: ByteBufferAllocator,
        logger: Logger
    )
}

struct BasicBenchmarkContext: BenchmarkContext {
    var coreContext: HBCoreRequestContext

    init(
        applicationContext: HBApplicationContext,
        eventLoop: EventLoop,
        allocator: ByteBufferAllocator,
        logger: Logger
    ) {
        self.coreContext = .init(applicationContext: applicationContext, eventLoop: eventLoop, allocator: allocator, logger: logger)
    }
}

/// Writes ByteBuffers to AsyncChannel outbound writer
struct BenchmarkBodyWriter: Sendable, HBResponseBodyWriter {
    func write(_ buffer: ByteBuffer) async throws {}
}

extension Benchmark {
    @discardableResult
    convenience init?<Context: BenchmarkContext>(
        name: String,
        context: Context.Type = BasicBenchmarkContext.self,
        configuration: Benchmark.Configuration = Benchmark.defaultConfiguration, 
        request: HTTPRequest,
        writeBody: @escaping @Sendable (HBStreamedRequestBody) async throws -> Void = { _ in },
        setupRouter: @escaping @Sendable (HBRouter<Context>) async throws -> Void
     ) {
        let router = HBRouter(context: Context.self)
        self.init(name, configuration: configuration) { benchmark in
            let responder = router.buildResponder()
            let applicationContext = HBApplicationContext(configuration: .init())
            benchmark.startMeasurement()

            try await withThrowingTaskGroup(of: Void.self) { group in
                for _ in benchmark.scaledIterations {
                    let context = Context.init(applicationContext: applicationContext, eventLoop: MultiThreadedEventLoopGroup.singleton.any(), allocator: ByteBufferAllocator(), logger: Logger(label: "Benchmark"))
                    let requestBodyStream = HBStreamedRequestBody()
                    let requestBody = HBRequestBody.stream(requestBodyStream)
                    let hbRequest = HBRequest(head: request, body: requestBody)
                    group.addTask {
                        let response = try await responder.respond(to: hbRequest, context: context)
                        try await response.body.write(BenchmarkBodyWriter())
                    }
                    try await writeBody(requestBodyStream)
                    requestBodyStream.finish()
                }
            }
        } setup: {
            try await setupRouter(router)
            Self.blackHole(MultiThreadedEventLoopGroup.singleton.any())
        }
    }
}

func routerBenchmarks() {
    Benchmark(
        name: "GET NoResponse", 
        request: .init(method: .get, scheme: "http", authority: "localhost", path: "/")
    ) { router in
        router.get { request, _ in
            HTTPResponse.Status.ok
        }
    }

    Benchmark(
        name: "Get Response", 
        request: .init(method: .get, scheme: "http", authority: "localhost", path: "/")
    ) { router in
        router.get { request, _ in
            HBResponse(status: .ok, headers: [:], body: .init { writer in
                try await writer.write(ByteBufferAllocator().buffer(repeating: 0, count: 16000))
                try await writer.write(ByteBufferAllocator().buffer(repeating: 0, count: 16000))
                try await writer.write(ByteBufferAllocator().buffer(repeating: 0, count: 16000))
                try await writer.write(ByteBufferAllocator().buffer(repeating: 0, count: 16000))
            })
        }
    }

    Benchmark(
        name: "PUT", 
        request: .init(method: .put, scheme: "http", authority: "localhost", path: "/")
    ) { bodyStream in
        await bodyStream.send(ByteBufferAllocator().buffer(repeating: 0, count: 16000))
        await bodyStream.send(ByteBufferAllocator().buffer(repeating: 0, count: 16000))
        await bodyStream.send(ByteBufferAllocator().buffer(repeating: 0, count: 16000))
        await bodyStream.send(ByteBufferAllocator().buffer(repeating: 0, count: 16000))
    } setupRouter: { router in
        router.put { request, _ in
            let body = try await request.body.collect(upTo: .max)
            return body.readableBytes.description
        }
    }

    Benchmark(
        name: "Echo", 
        request: .init(method: .post, scheme: "http", authority: "localhost", path: "/")
    ) { bodyStream in
        await bodyStream.send(ByteBufferAllocator().buffer(repeating: 0, count: 16000))
        await bodyStream.send(ByteBufferAllocator().buffer(repeating: 0, count: 16000))
        await bodyStream.send(ByteBufferAllocator().buffer(repeating: 0, count: 16000))
        await bodyStream.send(ByteBufferAllocator().buffer(repeating: 0, count: 16000))
    } setupRouter: { router in
        router.post { request, _ in
            HBResponse(status: .ok, headers: [:], body: .init { writer in
                for try await buffer in request.body {
                    try await writer.write(buffer)
                }
            })
        }
    }}