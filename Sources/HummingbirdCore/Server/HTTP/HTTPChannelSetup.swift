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

/// Internal error thrown when an unexpected HTTP part is received eg we didn't receive
/// a head part when we expected one
enum HTTPChannelError: Error {
    case unexpectedHTTPPart(HTTPServerRequestPart)
    case closeConnection
}

extension HTTPChannelSetup {
    public func handle(asyncChannel: NIOAsyncChannel<In, Out>, logger: Logger) async {
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                let responseWriter = HBHTTPServerBodyWriter(outbound: asyncChannel.outbound)
                var iterator = asyncChannel.inbound.makeAsyncIterator()
                while let part = try await iterator.next() {
                    guard case .head(let head) = part else {
                        throw HTTPChannelError.unexpectedHTTPPart(part)
                    }
                    let bodyStream = HBStreamedRequestBody()
                    let body = HBRequestBody.stream(bodyStream)
                    let request = HBHTTPRequest(head: head, body: body)
                    // add task processing request and writing response
                    group.addTask {
                        let response: HBHTTPResponse
                        do {
                            response = try await self.responder(request, asyncChannel.channel)
                        } catch {
                            response = self.getErrorResponse(from: error, allocator: asyncChannel.channel.allocator)
                        }
                        let head = HTTPResponseHead(version: request.head.version, status: response.status, headers: response.headers)
                        do {
                            try await asyncChannel.outbound.write(.head(head))
                            try await response.body.write(responseWriter)
                            try await asyncChannel.outbound.write(.end(nil))
                            // flush request body
                            for try await _ in request.body {}
                        } catch {
                            // flush request body
                            for try await _ in request.body {}
                            throw error
                        }
                        if request.head.headers["connection"].first == "close" {
                            throw HTTPChannelError.closeConnection
                        }
                    }
                    // send body parts to request
                    do {
                        // pass body part to request
                        while case .body(let buffer) = try await iterator.next() {
                            await bodyStream.send(buffer)
                        }
                        bodyStream.finish()
                    } catch {
                        // pass failed to read full http body to request
                        bodyStream.fail(error)
                    }
                    try await group.next()
                }
            }
        } catch {
            // we got here because we failed to either read or write to the channel
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
