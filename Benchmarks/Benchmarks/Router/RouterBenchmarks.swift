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
import HummingbirdCore
import HummingbirdRouter
import Logging
import NIOCore
import NIOEmbedded
import NIOHTTPTypes
import NIOPosix

/// Implementation of a basic request context that supports everything the Hummingbird library needs
struct BasicBenchmarkContext: RequestContext {
    typealias Source = BenchmarkRequestContextSource

    var coreContext: CoreRequestContextStorage

    init(source: Source) {
        self.coreContext = CoreRequestContextStorage(source: source)
    }
}

public struct BenchmarkRequestContextSource: RequestContextSource {
    public let logger = Logger(label: "Benchmark")
}

/// Writes ByteBuffers to AsyncChannel outbound writer
struct BenchmarkBodyWriter: Sendable, ResponseBodyWriter {
    func finish(_: HTTPFields?) async throws {}
    func write(_: ByteBuffer) async throws {}
}

/// Implementation of a basic request context that supports everything the Hummingbird library needs
struct BasicRouterBenchmarkContext: RouterRequestContext {
    typealias Source = BenchmarkRequestContextSource

    var coreContext: CoreRequestContextStorage
    var routerContext: RouterBuilderContext

    init(source: Source) {
        self.coreContext = CoreRequestContextStorage(source: source)
        self.routerContext = .init()
    }
}

typealias ByteBufferWriter = (ByteBuffer) async throws -> Void
extension Benchmark {
    @discardableResult
    convenience init?<ResponderBuilder: HTTPResponderBuilder>(
        _ name: String,
        configuration: Benchmark.Configuration = Benchmark.defaultConfiguration,
        request: HTTPRequest,
        writeBody: (@Sendable (ByteBufferWriter) async throws -> Void)? = nil,
        createRouter: @escaping @Sendable () async throws -> ResponderBuilder
    ) where ResponderBuilder.Responder.Context: RequestContext, ResponderBuilder.Responder.Context.Source == BenchmarkRequestContextSource {
        self.init(name, configuration: configuration) { benchmark in
            let responder = try await createRouter().buildResponder()

            if let writeBody {
                let context = ResponderBuilder.Responder.Context(source: BenchmarkRequestContextSource())

                benchmark.startMeasurement()

                for _ in benchmark.scaledIterations {
                    for _ in 0..<50 {
                        let (requestBody, source) = RequestBody.makeStream()
                        let Request = Request(head: request, body: requestBody)
                        try await writeBody(source.yield)
                        source.finish()
                        let response = try await responder.respond(to: Request, context: context)
                        _ = try await response.body.write(BenchmarkBodyWriter())
                    }
                }
            } else {
                let context = ResponderBuilder.Responder.Context(source: BenchmarkRequestContextSource())
                let (requestBody, source) = RequestBody.makeStream()
                let Request = Request(head: request, body: requestBody)
                source.finish()

                benchmark.startMeasurement()

                for _ in benchmark.scaledIterations {
                    for _ in 0..<50 {
                        let response = try await responder.respond(to: Request, context: context)
                        _ = try await response.body.write(BenchmarkBodyWriter())
                    }
                }
            }
        }
    }
}

struct EmptyMiddleware<Context>: RouterMiddleware {
    func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        try await next(request, context)
    }
}

extension HTTPField.Name {
    static let test = Self("Test")!
}

func routerBenchmarks() {
    let buffer = ByteBufferAllocator().buffer(repeating: 0xFF, count: 10000)
    Benchmark(
        "Router:GET",
        configuration: .init(warmupIterations: 10),
        request: .init(method: .get, scheme: "http", authority: "localhost", path: "/")
    ) {
        let router = Router(context: BasicBenchmarkContext.self)
        router.get { _, _ in
            buffer
        }
        return router
    }

    Benchmark(
        "Router:Parameters",
        configuration: .init(warmupIterations: 10),
        request: .init(method: .get, scheme: "http", authority: "localhost", path: "/testthis")
    ) {
        let router = Router(context: BasicBenchmarkContext.self)
        router.get("{test}") { _, context in
            try context.parameters.require("test")
        }
        return router
    }

    Benchmark(
        "Router:PUT",
        configuration: .init(warmupIterations: 10),
        request: .init(method: .put, scheme: "http", authority: "localhost", path: "/")
    ) { write in
        try await write(buffer)
        try await write(buffer)
        try await write(buffer)
        try await write(buffer)
    } createRouter: {
        let router = Router(context: BasicBenchmarkContext.self)
        router.put { request, _ in
            let body = try await request.body.collect(upTo: .max)
            return body.readableBytes.description
        }
        return router
    }

    Benchmark(
        "Router:Echo",
        configuration: .init(warmupIterations: 10),
        request: .init(method: .post, scheme: "http", authority: "localhost", path: "/")
    ) { write in
        try await write(buffer)
        try await write(buffer)
        try await write(buffer)
        try await write(buffer)
    } createRouter: {
        let router = Router(context: BasicBenchmarkContext.self)
        router.post { request, _ in
            Response(
                status: .ok,
                headers: [:],
                body: .init { writer in
                    for try await buffer in request.body {
                        try await writer.write(buffer)
                    }
                    try await writer.finish(nil)
                }
            )
        }
        return router
    }

    Benchmark(
        "Router:Middleware",
        configuration: .init(warmupIterations: 10),
        request: .init(method: .get, scheme: "http", authority: "localhost", path: "/")
    ) {
        let router = Router(context: BasicBenchmarkContext.self)
        router.middlewares.add(EmptyMiddleware())
        router.middlewares.add(EmptyMiddleware())
        router.middlewares.add(EmptyMiddleware())
        router.middlewares.add(EmptyMiddleware())
        router.get { _, _ in
            HTTPResponse.Status.ok
        }
        return router
    }

    Benchmark(
        "RouterBuilder:Middleware",
        configuration: .init(warmupIterations: 10),
        request: .init(method: .get, scheme: "http", authority: "localhost", path: "/")
    ) {
        let router = RouterBuilder(context: BasicRouterBenchmarkContext.self) {
            EmptyMiddleware()
            EmptyMiddleware()
            EmptyMiddleware()
            EmptyMiddleware()
            Get { _, _ -> HTTPResponse.Status in
                .ok
            }
        }
        return router
    }
}
