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

import Logging
import NIOCore

/// Protocol for objects generating a `HBHTTPResponse` from a `HBHTTPRequest`.
///
/// This is the core interface to the HummingbirdCore library. You need to provide an object that conforms
/// to `HBHTTPResponder` when you call `HTTPServer.start`. This object is used to define how
/// you convert requests to the server into responses.
///
/// This is an example `HBHTTPResponder` that replies with a response with body "Hello". Once you
/// have your response you need to call `onComplete`.
/// ```
/// struct HelloResponder: HBHTTPResponder {
///     func respond(
///         to request: HBHTTPRequest,
///         context: ChannelHandlerContext,
///         onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void
///     ) {
///         let responseHead = HTTPResponseHead(version: .init(major: 1, minor: 1), status: .ok)
///         let responseBody = context.channel.allocator.buffer(string: "Hello")
///         let response = HBHTTPResponse(head: responseHead, body: .byteBuffer(responseBody))
///         onComplete(.success(response))
///     }
/// }
/// ```
/// The following will start up a server using the above `HelloResponder`.
/// ```
/// let server = HBHTTPServer(
///     group: eventLoopGroup,
///     configuration: .init(address: .hostname("127.0.0.1", port: 8080))
/// )
/// try server.start(responder: HelloResponder()).wait()
/// ```
public protocol HBHTTPResponder {
    /// Passes request to be responded to and function to call when response is ready. It is required your implementation
    /// calls `onComplete` otherwise the server will never receive a response
    /// - Parameters:
    ///   - request: HTTP request
    ///   - context: ChannelHandlerContext from channel that request was served on.
    func respond(to request: HBHTTPRequest, channel: Channel) async throws -> HBHTTPResponse
}
