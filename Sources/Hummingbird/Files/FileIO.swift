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

/// Manages File reading and writing.
public struct FileIO: Sendable {
    let fileIO: NonBlockingFileIO
    let chunkSize: Int

    /// Initialize FileIO
    /// - Parameter application: application using FileIO
    public init(threadPool: NIOThreadPool = .singleton) {
        self.fileIO = .init(threadPool: threadPool)
        self.chunkSize = NonBlockingFileIO.defaultChunkSize
    }

    /// Load file and return response body
    ///
    /// Depending on the file size this will return either a response body containing a ByteBuffer or a stream that will provide the
    /// file in chunks.
    /// - Parameters:
    ///   - path: System file path
    ///   - context: Context this request is being called in
    /// - Returns: Response body
    public func loadFile(path: String, context: some BaseRequestContext) async throws -> ResponseBody {
        do {
            let stat = try await fileIO.lstat(path: path)
            return self.readFile(path: path, range: 0...numericCast(stat.st_size - 1), context: context)
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
    /// - Returns: Response body plus file size
    public func loadFile(path: String, range: ClosedRange<Int>, context: some BaseRequestContext) async throws -> ResponseBody {
        do {
            let stat = try await fileIO.lstat(path: path)
            let fileRange: ClosedRange<Int> = 0...numericCast(stat.st_size - 1)
            let range = range.clamped(to: fileRange)
            return self.readFile(path: path, range: range, context: context)
        } catch {
            throw HTTPError(.notFound)
        }
    }

    /// Write contents of request body to file
    ///
    /// This can be used to save arbitrary ByteBuffers by passing in `.byteBuffer(ByteBuffer)` as contents
    /// - Parameters:
    ///   - contents: Request body to write.
    ///   - path: Path to write to
    ///   - logger: Logger
    public func writeFile<AS: AsyncSequence>(
        contents: AS,
        path: String,
        context: some BaseRequestContext
    ) async throws where AS.Element == ByteBuffer {
        context.logger.debug("[FileIO] PUT", metadata: ["file": .string(path)])
        try await self.fileIO.withFileHandle(path: path, mode: .write, flags: .allowFileCreation()) { handle in
            for try await buffer in contents {
                try await self.fileIO.write(fileHandle: handle, buffer: buffer)
            }
        }
    }

    /// Write contents of request body to file
    ///
    /// This can be used to save arbitrary ByteBuffers by passing in `.byteBuffer(ByteBuffer)` as contents
    /// - Parameters:
    ///   - contents: Request body to write.
    ///   - path: Path to write to
    ///   - logger: Logger
    public func writeFile(
        buffer: ByteBuffer,
        path: String,
        context: some BaseRequestContext
    ) async throws {
        context.logger.debug("[FileIO] PUT", metadata: ["file": .string(path)])
        try await self.fileIO.withFileHandle(path: path, mode: .write, flags: .allowFileCreation()) { handle in
            try await self.fileIO.write(fileHandle: handle, buffer: buffer)
        }
    }

    /// Return response body that will read file
    func readFile(path: String, range: ClosedRange<Int>, context: some BaseRequestContext) -> ResponseBody {
        return ResponseBody(contentLength: range.count) { writer in
            try await self.fileIO.withFileHandle(path: path, mode: .read) { handle in
                let endOffset = range.endIndex
                let chunkSize = 8 * 1024
                var fileOffset = range.startIndex

                while case .inRange(let offset) = fileOffset {
                    let bytesLeft = range.distance(from: fileOffset, to: endOffset)
                    let bytesToRead = Swift.min(chunkSize, bytesLeft)
                    let buffer = try await self.fileIO.read(
                        fileHandle: handle,
                        fromOffset: numericCast(offset),
                        byteCount: bytesToRead,
                        allocator: context.allocator
                    )
                    fileOffset = range.index(fileOffset, offsetBy: bytesToRead)
                    try await writer.write(buffer)
                }
            }
        }
    }
}
