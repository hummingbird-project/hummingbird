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

import Atomics
import Logging
import NIOCore
import NIOHTTP1
import ServiceLifecycle

/// Protocol for HTTP channels
public protocol HTTPChannelHandler: HBChannelSetup {
    var responder: @Sendable (HBHTTPRequest, Channel) async throws -> HBHTTPResponse { get set }
}

/// Internal error thrown when an unexpected HTTP part is received eg we didn't receive
/// a head part when we expected one
enum HTTPChannelError: Error {
    case unexpectedHTTPPart(HTTPServerRequestPart)
    case closeConnection
}

enum HTTPState: Int, AtomicValue {
    case idle
    case processing
    case cancelled
}

extension HTTPChannelHandler {
    public func handleHTTP(asyncChannel: NIOAsyncChannel<HTTPServerRequestPart, SendableHTTPServerResponsePart>, logger: Logger) async {
        let processingRequest = ManagedAtomic(HTTPState.idle)
        do {
            try await withGracefulShutdownHandler {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    try await asyncChannel.executeThenClose { inbound, outbound in 
                        let responseWriter = HBHTTPServerBodyWriter(outbound: outbound)
                        var iterator = inbound.makeAsyncIterator()
                        while let part = try await iterator.next() {
                            // set to processing unless it is cancelled then exit
                            guard processingRequest.exchange(.processing, ordering: .relaxed) == .idle else { break }
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
                                    try await outbound.write(.head(head))
                                    try await response.body.write(responseWriter)
                                    try await outbound.write(.end(nil))
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
                            // set to idle unless it is cancelled then exit
                            guard processingRequest.exchange(.idle, ordering: .relaxed) == .processing else { break }
                        }
                    }
                }
            } onGracefulShutdown: {
                // set to cancelled
                if processingRequest.exchange(.cancelled, ordering: .relaxed) == .idle {
                // only close the channel input if it is idle 
                    asyncChannel.channel.close(mode: .input, promise: nil)
                }
            }
        } catch HTTPChannelError.closeConnection {
            // channel is being closed because we received a connection: close header
        } catch {
            // we got here because we failed to either read or write to the channel
            logger.trace("Failed to read/write to Channel. Error: \(error)")
        }
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
