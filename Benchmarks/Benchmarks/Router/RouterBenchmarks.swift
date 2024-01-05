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

import Benchmark
import HTTPTypes
import Hummingbird
import NIOHTTPTypes
@_spi(HBXCT) import HummingbirdCore
import Logging
import NIOCore
import NIOPosix

/// Implementation of a basic request context that supports everything the Hummingbird library needs
struct BasicBenchmarkContext: HBBaseRequestContext {
    var coreContext: HBCoreRequestContext

    init(
        allocator: ByteBufferAllocator,
        logger: Logger
    ) {
        self.coreContext = .init(allocator: allocator, logger: logger)
    }
}

/// Writes ByteBuffers to AsyncChannel outbound writer
struct BenchmarkBodyWriter: Sendable, HBResponseBodyWriter {
    func write(_: ByteBuffer) async throws {}
}

extension Benchmark {
    @discardableResult
    convenience init?<Context: HBBaseRequestContext>(
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
            benchmark.startMeasurement()

            for _ in benchmark.scaledIterations {
                for _ in 0..<50 {
                    try await withThrowingTaskGroup(of: Void.self) { group in
                        let context = Context(
                            allocator: ByteBufferAllocator(), 
                            logger: Logger(label: "Benchmark")
                        )
                        let requestBodyStream = HBStreamedRequestBody()
                        let requestBody = HBRequestBody.stream(requestBodyStream)
                        let hbRequest = HBRequest(head: request, body: requestBody)
                        group.addTask {
                            let response = try await responder.respond(to: hbRequest, context: context)
                            _ = try await response.body.write(BenchmarkBodyWriter())
                        }
                        try await writeBody(requestBodyStream)
                        requestBodyStream.finish()
                    }
                }
            }
        } setup: {
            try await setupRouter(router)
            Self.blackHole(MultiThreadedEventLoopGroup.singleton.any())
        }
    }
}

extension HTTPField.Name {
    static let test = Self("Test")!
}

func routerBenchmarks() {
    let buffer = ByteBufferAllocator().buffer(repeating: 0xff, count: 10000)
    Benchmark(
        name: "Router:GET",
        configuration: .init(warmupIterations: 10),
        request: .init(method: .get, scheme: "http", authority: "localhost", path: "/")
    ) { router in
        router.get { _, _ in
            buffer
        }
    }

    Benchmark(
        name: "Router:PUT",
        configuration: .init(warmupIterations: 10),
        request: .init(method: .put, scheme: "http", authority: "localhost", path: "/")
    ) { bodyStream in
        await bodyStream.send(buffer)
        await bodyStream.send(buffer)
        await bodyStream.send(buffer)
        await bodyStream.send(buffer)
    } setupRouter: { router in
        router.put { request, _ in
            let body = try await request.body.collate(maxSize: .max)
            return body.readableBytes.description
        }
    }

    Benchmark(
        name: "Router:Echo",
        configuration: .init(warmupIterations: 10),
        request: .init(method: .post, scheme: "http", authority: "localhost", path: "/")
    ) { bodyStream in
        await bodyStream.send(buffer)
        await bodyStream.send(buffer)
        await bodyStream.send(buffer)
        await bodyStream.send(buffer)
    } setupRouter: { router in
        router.post { request, _ in
            HBResponse(status: .ok, headers: [:], body: .init { writer in
                for try await buffer in request.body {
                    try await writer.write(buffer)
                    return nil
                }
            })
        }
    }

    Benchmark(
        name: "Middleware Chain",
        configuration: .init(warmupIterations: 10),
        request: .init(method: .get, scheme: "http", authority: "localhost", path: "/")
    ) { router in
        struct EmptyMiddleware<Context>: HBMiddlewareProtocol {
            func handle(_ request: HBRequest, context: Context, next: (HBRequest, Context) async throws -> HBResponse) async throws -> HBResponse {
                return try await next(request, context)
            }
        }
        router.middlewares.add(EmptyMiddleware())
        router.middlewares.add(EmptyMiddleware())
        router.middlewares.add(EmptyMiddleware())
        router.middlewares.add(EmptyMiddleware())
        router.get { _, _ in
            HTTPResponse.Status.ok
        }
    }
}
