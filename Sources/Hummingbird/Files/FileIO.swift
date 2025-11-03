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

#if !os(Windows)
import CNIOLinux
public import HummingbirdCore
import Logging
public import NIOCore
public import NIOPosix

/// Manages File reading and writing.
public struct FileIO: Sendable {
    let fileIO: NonBlockingFileIO

    /// Initialize FileIO
    /// - Parameter threadPool: ThreadPool to use for file operations
    public init(threadPool: NIOThreadPool = .singleton) {
        self.fileIO = .init(threadPool: threadPool)
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
        chunkLength: Int = NonBlockingFileIO.defaultChunkSize
    ) async throws -> ResponseBody {
        do {
            let stat = try await fileIO.stat(path: path)
            guard stat.st_size > 0 else { return .init() }
            return self.readFile(path: path, range: 0...numericCast(stat.st_size - 1), context: context, chunkLength: chunkLength)
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
        chunkLength: Int = NonBlockingFileIO.defaultChunkSize
    ) async throws -> ResponseBody {
        do {
            let stat = try await fileIO.stat(path: path)
            guard stat.st_size > 0 else { return .init() }
            let fileRange: ClosedRange<Int> = 0...numericCast(stat.st_size - 1)
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
        try await self.fileIO.withFileHandle(path: path, mode: .write, flags: .allowFileCreation()) { handle in
            for try await buffer in contents {
                try await self.fileIO.write(fileHandle: handle, buffer: buffer)
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
        try await self.fileIO.withFileHandle(path: path, mode: .write, flags: .allowFileCreation()) { handle in
            try await self.fileIO.write(fileHandle: handle, buffer: buffer)
        }
    }

    /// Return response body that will read file
    func readFile(
        path: String,
        range: ClosedRange<Int>,
        context: some RequestContext,
        chunkLength: Int = NonBlockingFileIO.defaultChunkSize
    ) -> ResponseBody {
        ResponseBody(contentLength: range.count) { writer in
            try await self.fileIO.withFileHandle(path: path, mode: .read) { handle in
                let endOffset = range.endIndex
                let chunkLength = chunkLength
                var fileOffset = range.startIndex
                let allocator = ByteBufferAllocator()

                while case .inRange(let offset) = fileOffset {
                    let bytesLeft = range.distance(from: fileOffset, to: endOffset)
                    let bytesToRead = Swift.min(chunkLength, bytesLeft)
                    let buffer = try await self.fileIO.read(
                        fileHandle: handle,
                        fromOffset: numericCast(offset),
                        byteCount: bytesToRead,
                        allocator: allocator
                    )
                    fileOffset = range.index(fileOffset, offsetBy: bytesToRead)
                    try await writer.write(buffer)
                }
                try await writer.finish(nil)
            }
        }
    }
}

extension NonBlockingFileIO {
    func stat(path: String) async throws -> stat {
        let stat = try await self.lstat(path: path)
        if stat.st_mode & S_IFMT == S_IFLNK {
            let realPath = try await self.readlink(path: path)
            return try await self.lstat(path: realPath)
        } else {
            return stat
        }
    }
}
#endif