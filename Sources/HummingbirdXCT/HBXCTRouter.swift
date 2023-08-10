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

import Hummingbird
import NIOCore
import NIOPosix

/// Test sending values to requests to router. This does not setup a live server
struct HBXCTRouter: HBXCT {
    /// Dummy request context
    struct RequestContext: HBRequestContext {
        let eventLoop: EventLoop
        var allocator: ByteBufferAllocator { ByteBufferAllocator() }
        var remoteAddress: SocketAddress? { return nil }
    }

    init() {
        #if os(iOS)
        self.eventLoopGroup = NIOTSEventLoopGroup()
        #else
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        #endif
    }

    /// Run test
    func run(application: HBApplication, _ test: @escaping @Sendable (HBXCTClientProtocol) async throws -> Void) async throws {
        let router = application.router.buildRouter()
        try await test(Client(responder: router, application: application))
        try application.shutdownApplication()
    }

    /// HBXCTRouter client. Constructs an `HBRequest` sends it to the router and then converts
    /// resulting response back to XCT response type
    struct Client: HBXCTClientProtocol {
        let responder: HBResponder
        let application: HBApplication

        func execute(uri: String, method: HTTPMethod, headers: HTTPHeaders, body: ByteBuffer?) async throws -> HBXCTResponse {
            let eventLoop = self.application.eventLoopGroup.any()
            let request = HBRequest(
                head: .init(version: .http1_1, method: method, uri: uri, headers: headers),
                body: .byteBuffer(body),
                application: application,
                context: RequestContext(eventLoop: eventLoop)
            )
            let response: HBResponse
            do {
                response = try await self.responder.respond(to: request)
            } catch let error as HBHTTPResponseError {
                let httpResponse = error.response(version: .http1_1, allocator: ByteBufferAllocator())
                response = .init(status: httpResponse.head.status, headers: httpResponse.head.headers, body: httpResponse.body)
            } catch {
                response = .init(status: .internalServerError)
            }
            let body: ByteBuffer?
            switch response.body {
            case .byteBuffer(let buffer):
                body = buffer
            case .empty:
                body = nil
            case .stream(let streamer):
                var colllateBuffer = ByteBuffer()
                streamerReadLoop:
                    while true
                {
                    switch try await streamer.read(on: eventLoop).get() {
                    case .byteBuffer(var part):
                        colllateBuffer.writeBuffer(&part)
                    case .end:
                        break streamerReadLoop
                    }
                }
                body = colllateBuffer
            }
            return .init(status: response.status, headers: response.headers, body: body)
        }
    }

    var eventLoopGroup: EventLoopGroup
}
