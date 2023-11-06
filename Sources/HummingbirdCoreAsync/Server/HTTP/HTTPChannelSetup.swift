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

import Logging
import NIOCore
import NIOHTTP1

/// Protocol for HTTP channels
public protocol HTTPChannelSetup: HBChannelSetup where In == HTTPServerRequestPart, Out == SendableHTTPServerResponsePart {
    var responder: @Sendable (HBHTTPRequest, Channel) async throws -> HBHTTPResponse { get }
}

extension HTTPChannelSetup {
    public func handle(asyncChannel: NIOAsyncChannel<In, Out>, logger: Logger) async {
        do {
            try await withThrowingDiscardingTaskGroup { group in
                let responseWriter = HBHTTPServerBodyWriter(outbound: asyncChannel.outbound)
                var iterator = asyncChannel.inbound.makeAsyncIterator()
                while true {
                    guard let part = try await iterator.next() else { break }
                    guard case .head(let head) = part else {
                        print("Unexpected HTTP part")
                        fatalError()
                    }
                    let body = HBRequestBody()
                    let request = HBHTTPRequest(head: head, body: body)
                    group.addTask {
                        let response: HBHTTPResponse
                        do {
                            response = try await self.responder(request, asyncChannel.channel)
                        } catch {
                            response = self.getErrorResponse(from: error, allocator: asyncChannel.channel.allocator)
                        }
                        let head = HTTPResponseHead(version: .http1_1, status: response.status, headers: response.headers)
                        try await asyncChannel.outbound.write(.head(head))
                        try await response.body.write(responseWriter)
                        try await asyncChannel.outbound.write(.end(nil))
                        // flush request body
                        for try await _ in request.body {}
                    }

                    do {
                        // pass body part to request
                        while case .body(let buffer) = try await iterator.next() {
                            await body.send(buffer)
                        }
                        body.finish()
                    } catch {
                        body.fail(error)
                        group.cancelAll()
                    }
                }
            }
        } catch {
            print(error)
            fatalError()
        }
        asyncChannel.outbound.finish()
    }

    func getErrorResponse(from error: Error, allocator: ByteBufferAllocator) -> HBHTTPResponse {
        switch error {
        case let httpError as HBHTTPResponseError:
            // this is a processed error so don't log as Error
            return httpError.response(allocator: allocator)
        default:
            // this error has not been recognised
            return HBHTTPResponse(
                status: .internalServerError,
                body: .init()
            )
        }
    }
}

/// Writes ByteBuffers to AsyncChannel outbound writer
struct HBHTTPServerBodyWriter: Sendable, HBResponseBodyWriter {
    typealias Out = SendableHTTPServerResponsePart
    /// The components of a HTTP response from the view of a HTTP server.
    public typealias OutboundWriter = NIOAsyncChannelOutboundWriter<Out>

    let outbound: OutboundWriter

    func write(_ buffer: ByteBuffer) async throws {
        try await self.outbound.write(.body(buffer))
    }
}
