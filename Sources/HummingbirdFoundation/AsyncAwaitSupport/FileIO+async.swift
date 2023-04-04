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

import Hummingbird
import Logging

/// Middleware using async/await
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension HBFileIO {
    /// Load file and return response body
    ///
    /// Depending on the file size this will return either a response body containing a ByteBuffer or a stream that will provide the
    /// file in chunks.
    /// - Parameters:
    ///   - path: System file path
    ///   - context: Context this request is being called in
    /// - Returns: Response body
    public func loadFile(path: String, context: HBRequestContext, logger: Logger) async throws -> HBResponseBody {
        return try await self.loadFile(path: path, context: context, logger: logger).get()
    }

    /// Load part of file and return response body.
    ///
    /// Depending on the size of the part this will return either a response body containing a ByteBuffer or a stream that will provide the
    /// file in chunks.
    /// - Parameters:
    ///   - path: System file path
    ///   - range:Range defining how much of the file is to be loaded
    ///   - context: Context this request is being called in
    /// - Returns: Response body plus file size
    public func loadFile(
        path: String,
        range: ClosedRange<Int>,
        context: HBRequestContext,
        logger: Logger
    ) async throws -> (HBResponseBody, Int) {
        return try await self.loadFile(path: path, range: range, context: context, logger: logger).get()
    }

    /// Write contents of request body to file
    ///
    /// This can be used to save arbitrary ByteBuffers by passing in `.byteBuffer(ByteBuffer)` as contents
    /// - Parameters:
    ///   - contents: Request body to write.
    ///   - path: Path to write to
    ///   - eventLoop: EventLoop everything runs on
    ///   - logger: Logger
    public func writeFile(contents: HBRequestBody, path: String, context: HBRequestContext, logger: Logger) async throws {
        try await self.writeFile(contents: contents, path: path, context: context, logger: logger).get()
    }
}
