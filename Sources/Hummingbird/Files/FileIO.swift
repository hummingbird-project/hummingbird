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

import HummingbirdCore
import Logging
import NIOCore
import NIOPosix
import NIOFileSystem

/// Manages File reading and writing.
public struct FileIO: Sendable {
    struct FileError: Error {
        internal enum Value {
            case fileDoesNotExist
        }
        internal let value: Value

        static var fileDoesNotExist: Self { .init(value: .fileDoesNotExist) }
    }
    let fileSystem: FileSystem

    /// Initialize FileIO
    /// - Parameter threadPool: ThreadPool to use for file operations
    public init(threadPool: NIOThreadPool = .singleton) {
        self.fileSystem = .init(threadPool: threadPool)
    }

    /// Load file and return response body
    ///
    /// Depending on the file size this will return either a response body containing a ByteBuffer or a stream that will provide the
    /// file in chunks.
    /// - Parameters:
    ///   - path: System file path
    ///   - context: Context this request is being called in
    ///   - chunkLength: Size of the chunks read from disk and loaded into memory (in bytes). Defaults to the value suggested by `swift-nio`.
    /// - Returns: Response body
    public func loadFile(
        path: String,
        context: some RequestContext,
        chunkLength: Int = 128 * 1024
    ) async throws -> ResponseBody {
        do {
            guard let info = try await self.fileSystem.info(forFileAt: .init(path)) else { throw FileError.fileDoesNotExist }
            guard info.size > 0 else { return .init() }
            return self.readFile(path: path, range: 0...numericCast(info.size - 1), context: context, chunkLength: chunkLength)
        } catch {
            throw HTTPError(.notFound)
        }
    }

    /// Load part of file and return response body.
    ///
    /// Depending on the size of the part this will return either a response body containing a ByteBuffer or a stream that will provide the
    /// file in chunks.
    /// - Parameters:
    ///   - path: System file path
    ///   - range:Range defining how much of the file is to be loaded
    ///   - context: Context this request is being called in
    ///   - chunkLength: Size of the chunks read from disk and loaded into memory (in bytes). Defaults to the value suggested by `swift-nio`.
    /// - Returns: Response body plus file size
    public func loadFile(
        path: String,
        range: ClosedRange<Int>,
        context: some RequestContext,
        chunkLength: Int = 128 * 1024
    ) async throws -> ResponseBody {
        do {
            guard let info = try await self.fileSystem.info(forFileAt: .init(path)) else { throw FileError.fileDoesNotExist }
            guard info.size > 0 else { return .init() }
            let fileRange: ClosedRange<Int> = 0...numericCast(info.size - 1)
            let range = range.clamped(to: fileRange)
            return self.readFile(path: path, range: range, context: context, chunkLength: chunkLength)
        } catch {
            throw HTTPError(.notFound)
        }
    }

    /// Write contents of AsyncSequence of buffers to file
    ///
    /// - Parameters:
    ///   - contents: AsyncSequence of buffers to write.
    ///   - path: Path to write to
    ///   - context: Request Context
    public func writeFile<AS: AsyncSequence>(
        contents: AS,
        path: String,
        context: some RequestContext
    ) async throws where AS.Element == ByteBuffer {
        context.logger.debug("[FileIO] PUT", metadata: ["hb.file.path": .string(path)])
        try await self.fileSystem.withFileHandle(
            forWritingAt: .init(path),
            options: .newFile(replaceExisting: true)
        ) { fileHandle in
            try await fileHandle.withBufferedWriter { writer in
                _ = try await writer.write(contentsOf: contents)
            }
        }
    }

    /// Write contents of buffer to file
    ///
    /// - Parameters:
    ///   - buffer: ByteBuffer to write.
    ///   - path: Path to write to
    ///   - context: Request Context
    public func writeFile(
        buffer: ByteBuffer,
        path: String,
        context: some RequestContext
    ) async throws {
        context.logger.debug("[FileIO] PUT", metadata: ["hb.file.path": .string(path)])
        try await self.fileSystem.withFileHandle(
            forWritingAt: .init(path),
            options: .newFile(replaceExisting: true)
        ) { fileHandle in
            _ = try await fileHandle.write(contentsOf: buffer, toAbsoluteOffset: 0)
        }
    }

    /// Return response body that will read file
    func readFile(
        path: String,
        range: ClosedRange<Int>,
        context: some RequestContext,
        chunkLength: Int
    ) -> ResponseBody {
        ResponseBody(contentLength: range.count) { writer in
            try await self.fileSystem.withFileHandle(forReadingAt: .init(path)) { fileHandle in
                let startOffset: Int64 = numericCast(range.lowerBound)
                let endOffset: Int64 = numericCast(range.upperBound)

                for try await chunk in fileHandle.readChunks(in: startOffset...endOffset, chunkLength: .bytes(numericCast(chunkLength))) {
                    try await writer.write(chunk)
                }
                try await writer.finish(nil)
            }
        }
    }
}
