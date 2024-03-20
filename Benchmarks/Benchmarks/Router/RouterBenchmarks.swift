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
import NIOEmbedded
import NIOHTTPTypes
@_spi(Internal) import HummingbirdCore
import Logging
import NIOCore
import NIOPosix

/// Implementation of a basic request context that supports everything the Hummingbird library needs
struct BasicBenchmarkContext: RequestContext {
    var coreContext: CoreRequestContext

    public init(channel: Channel, logger: Logger) {
        self.coreContext = .init(allocator: channel.allocator, logger: logger)
    }
}

/// Writes ByteBuffers to AsyncChannel outbound writer
struct BenchmarkBodyWriter: Sendable, ResponseBodyWriter {
    func write(_: ByteBuffer) async throws {}
}

typealias ByteBufferWriter = (ByteBuffer) async throws -> Void
extension Benchmark {
    @discardableResult
    convenience init?<Context: RequestContext>(
        name: String,
        context: Context.Type = BasicBenchmarkContext.self,
        configuration: Benchmark.Configuration = Benchmark.defaultConfiguration,
        request: HTTPRequest,
        writeBody: @escaping @Sendable (ByteBufferWriter) async throws -> Void = { _ in },
        setupRouter: @escaping @Sendable (Router<Context>) async throws -> Void
    ) {
        let router = Router(context: Context.self)
        self.init(name, configuration: configuration) { benchmark in
            let responder = router.buildResponder()
            benchmark.startMeasurement()

            for _ in benchmark.scaledIterations {
                for _ in 0..<50 {
                    try await withThrowingTaskGroup(of: Void.self) { group in
                        let context = Context(
                            channel: EmbeddedChannel(),
                            logger: Logger(label: "Benchmark")
                        )
                        let (requestBody, source) = RequestBody.makeStream()
                        let Request = Request(head: request, body: requestBody)
                        group.addTask {
                            let response = try await responder.respond(to: Request, context: context)
                            _ = try await response.body.write(BenchmarkBodyWriter())
                        }
                        try await writeBody(source.yield)
                        source.finish()
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
    let buffer = ByteBufferAllocator().buffer(repeating: 0xFF, count: 10000)
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
    ) { write in
        try await write(buffer)
        try await write(buffer)
        try await write(buffer)
        try await write(buffer)
    } setupRouter: { router in
        router.put { request, _ in
            let body = try await request.body.collect(upTo: .max)
            return body.readableBytes.description
        }
    }

    Benchmark(
        name: "Router:Echo",
        configuration: .init(warmupIterations: 10),
        request: .init(method: .post, scheme: "http", authority: "localhost", path: "/")
    ) { write in
        try await write(buffer)
        try await write(buffer)
        try await write(buffer)
        try await write(buffer)
    } setupRouter: { router in
        router.post { request, _ in
            Response(status: .ok, headers: [:], body: .init { writer in
                for try await buffer in request.body {
                    try await writer.write(buffer)
                }
            })
        }
    }

    Benchmark(
        name: "Middleware Chain",
        configuration: .init(warmupIterations: 10),
        request: .init(method: .get, scheme: "http", authority: "localhost", path: "/")
    ) { router in
        struct EmptyMiddleware<Context>: RouterMiddleware {
            func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
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
