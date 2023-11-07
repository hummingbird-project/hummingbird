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
import HummingbirdCore
import Logging
import NIOCore
import NIOPosix

/// Manages File reading and writing.
public struct HBFileIO: Sendable {
    let fileIO: NonBlockingFileIO
    let chunkSize: Int

    /// Initialize FileIO
    /// - Parameter application: application using FileIO
    public init(threadPool: NIOThreadPool) {
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
    public func loadFile(path: String, context: HBRequestContext, logger: Logger) async throws -> HBResponseBody {
        do {
            let (handle, region) = try await self.fileIO.openFile(path: path, eventLoop: context.eventLoop).get()
            logger.debug("[FileIO] GET", metadata: ["file": .string(path)])

            if region.readableBytes > self.chunkSize {
                return try self.streamFile(handle: handle, region: region, context: context)
            } else {
                // only close file handle for load, as streamer hasn't loaded data at this point
                defer {
                    try? handle.close()
                }
                return try await self.loadFile(handle: handle, region: region, context: context)
            }
        } catch {
            throw HBHTTPError(.notFound)
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
    public func loadFile(path: String, range: ClosedRange<Int>, context: HBRequestContext, logger: Logger) async throws -> (HBResponseBody, Int) {
        do {
            let (handle, region) = try await self.fileIO.openFile(path: path, eventLoop: context.eventLoop).get()
            logger.debug("[FileIO] GET", metadata: ["file": .string(path)])

            // work out region to load
            let regionRange = region.readerIndex...region.endIndex
            let range = range.clamped(to: regionRange)
            // add one to upperBound as range is inclusive of upper bound
            let loadRegion = FileRegion(fileHandle: handle, readerIndex: range.lowerBound, endIndex: range.upperBound + 1)

            if loadRegion.readableBytes > self.chunkSize {
                let stream = try self.streamFile(handle: handle, region: loadRegion, context: context)
                return (stream, region.readableBytes)
            } else {
                // only close file handle for load, as streamer hasn't loaded data at this point
                defer {
                    try? handle.close()
                }
                let buffer = try await self.loadFile(handle: handle, region: loadRegion, context: context)
                return (buffer, region.readableBytes)
            }
        } catch {
            throw HBHTTPError(.notFound)
        }
    }

    /// Write contents of request body to file
    ///
    /// This can be used to save arbitrary ByteBuffers by passing in `.byteBuffer(ByteBuffer)` as contents
    /// - Parameters:
    ///   - contents: Request body to write.
    ///   - path: Path to write to
    ///   - logger: Logger
    public func writeFile(contents: HBRequestBody, path: String, context: HBRequestContext, logger: Logger) async throws {
        let handle = try await self.fileIO.openFile(path: path, mode: .write, flags: .allowFileCreation(), eventLoop: context.eventLoop).get()
        defer {
            try? handle.close()
        }
        logger.debug("[FileIO] PUT", metadata: ["file": .string(path)])
        switch contents {
        case .byteBuffer(let buffer):
            try await self.writeFile(buffer: buffer, handle: handle, on: context.eventLoop)
        case .stream(let streamer):
            try await self.writeFile(asyncSequence: streamer, handle: handle, on: context.eventLoop)
        }
    }

    /// Load file as ByteBuffer
    func loadFile(handle: NIOFileHandle, region: FileRegion, context: HBRequestContext) async throws -> HBResponseBody {
        let buffer = try await self.fileIO.read(
            fileHandle: handle,
            fromOffset: Int64(region.readerIndex),
            byteCount: region.readableBytes,
            allocator: context.allocator,
            eventLoop: context.eventLoop
        ).get()
        return .init(byteBuffer: buffer)
    }

    /// Return streamer that will load file
    func streamFile(handle: NIOFileHandle, region: FileRegion, context: HBRequestContext) throws -> HBResponseBody {
        let fileOffset = region.readerIndex
        let endOffset = region.endIndex
        return HBResponseBody(contentLength: region.readableBytes) { writer in
            let chunkSize = 8 * 1024
            var fileOffset = fileOffset

            while fileOffset < endOffset {
                let bytesLeft = endOffset - fileOffset
                let bytesToRead = Swift.min(chunkSize, bytesLeft)
                let fileOffsetToRead = fileOffset
                let buffer = try await self.fileIO.read(
                    fileHandle: handle,
                    fromOffset: Int64(fileOffsetToRead),
                    byteCount: bytesToRead,
                    allocator: context.allocator,
                    eventLoop: context.eventLoop
                ).get()
                fileOffset += bytesToRead
                try await writer.write(buffer)
            }
            try handle.close()
        }
    }

    /// write byte buffer to file
    func writeFile(buffer: ByteBuffer, handle: NIOFileHandle, on eventLoop: EventLoop) async throws {
        return try await self.fileIO.write(fileHandle: handle, buffer: buffer, eventLoop: eventLoop).get()
    }

    /// write output of streamer to file
    func writeFile<BufferSequence: AsyncSequence>(
        asyncSequence: BufferSequence,
        handle: NIOFileHandle,
        on eventLoop: EventLoop
    ) async throws where BufferSequence.Element == ByteBuffer {
        for try await buffer in asyncSequence {
            try await self.fileIO.write(fileHandle: handle, buffer: buffer, eventLoop: eventLoop).get()
        }
    }
}
