import Hummingbird
import Logging
import NIO

/// Manages File loading. Can either stream or load file.
public struct HBFileIO {
    let fileIO: NonBlockingFileIO
    let chunkSize: Int

    /// Initialize FileIO
    /// - Parameter application: application using FileIO
    public init(application: HBApplication) {
        self.fileIO = .init(threadPool: application.threadPool)
        self.chunkSize = NonBlockingFileIO.defaultChunkSize
    }

    /// Return details about file, without downloading it
    /// - Parameters:
    ///   - request: request for file
    ///   - path: System file path
    /// - Returns: Response including file details
    public func headFile(path: String, context: HBRequest.Context) -> EventLoopFuture<HBResponse> {
        return self.fileIO.openFile(path: path, eventLoop: context.eventLoop).flatMap { handle, region in
            context.logger.debug("[FileIO] HEAD", metadata: ["file": .string(path)])
            let headers: HTTPHeaders = ["content-length": region.readableBytes.description]
            let response = HBResponse(status: .ok, headers: headers, body: .empty)
            try? handle.close()
            return context.eventLoop.makeSucceededFuture(response)
        }.flatMapErrorThrowing { _ in
            throw HBHTTPError(.notFound)
        }
    }

    /// Load file and return response body
    ///
    /// Depending on the file size this will return either a response body containing a ByteBuffer or a stream that will provide the
    /// file in chunks.
    /// - Parameters:
    ///   - path: System file path
    ///   - context: Context this request is being called in
    /// - Returns: Response body plus file size
    public func loadFile(path: String, context: HBRequest.Context) -> EventLoopFuture<HBResponseBody> {
        return self.fileIO.openFile(path: path, eventLoop: context.eventLoop).flatMap { handle, region in
            context.logger.debug("[FileIO] GET", metadata: ["file": .string(path)])

            let futureResult: EventLoopFuture<HBResponseBody>
            if region.readableBytes > self.chunkSize {
                futureResult = streamFile(handle: handle, region: region, context: context)
            } else {
                futureResult = loadFile(handle: handle, region: region, context: context)
                // only close file handle for load, as streamer hasn't loaded data at this point
                futureResult.whenComplete { _ in
                    try? handle.close()
                }
            }
            return futureResult
        }.flatMapErrorThrowing { _ in
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
    public func loadFile(path: String, range: ClosedRange<Int>, context: HBRequest.Context) -> EventLoopFuture<(HBResponseBody, Int)> {
        return self.fileIO.openFile(path: path, eventLoop: context.eventLoop).flatMap { handle, region in
            context.logger.debug("[FileIO] GET", metadata: ["file": .string(path)])

            // work out region to load
            let regionRange = region.readerIndex...region.endIndex
            let range = range.clamped(to: regionRange)
            // add one to upperBound as range is inclusive of upper bound
            let loadRegion = FileRegion(fileHandle: handle, readerIndex: range.lowerBound, endIndex: range.upperBound + 1)

            let futureResult: EventLoopFuture<(HBResponseBody, Int)>
            if loadRegion.readableBytes > self.chunkSize {
                futureResult = streamFile(handle: handle, region: loadRegion, context: context)
                    .map { ($0, region.readableBytes) }
            } else {
                futureResult = loadFile(handle: handle, region: loadRegion, context: context)
                    .map { ($0, region.readableBytes) }
                // only close file handle for load, as streamer hasn't loaded data at this point
                futureResult.whenComplete { _ in
                    try? handle.close()
                }
            }
            return futureResult
        }.flatMapErrorThrowing { _ in
            throw HBHTTPError(.notFound)
        }
    }

    /// Write contents of request body to file
    ///
    /// This can be used to save arbitrary ByteBuffers by passing in `.byteBuffer(ByteBuffer)` as contents
    /// - Parameters:
    ///   - contents: Request body to write.
    ///   - path: Path to write to
    ///   - eventLoop: EventLoop everything runs on
    ///   - logger: Logger
    /// - Returns: EventLoopFuture fulfilled when everything is done
    public func writeFile(contents: HBRequestBody, path: String, context: HBRequest.Context) -> EventLoopFuture<Void> {
        return self.fileIO.openFile(path: path, mode: .write, flags: .allowFileCreation(), eventLoop: context.eventLoop).flatMap { handle in
            context.logger.debug("[FileIO] PUT", metadata: ["file": .string(path)])
            let futureResult: EventLoopFuture<Void>
            switch contents {
            case .byteBuffer(let buffer):
                guard let buffer = buffer else { return context.eventLoop.makeSucceededFuture(()) }
                futureResult = writeFile(buffer: buffer, handle: handle, on: context.eventLoop)
            case .stream(let streamer):
                futureResult = writeFile(stream: streamer, handle: handle, on: context.eventLoop)
            }
            futureResult.whenComplete { _ in
                try? handle.close()
            }
            return futureResult
        }
    }

    /// Load file as ByteBuffer
    func loadFile(handle: NIOFileHandle, region: FileRegion, context: HBRequest.Context) -> EventLoopFuture<HBResponseBody> {
        return self.fileIO.read(
            fileHandle: handle,
            fromOffset: Int64(region.readerIndex),
            byteCount: region.readableBytes,
            allocator: context.allocator,
            eventLoop: context.eventLoop
        ).map { buffer in
            return .byteBuffer(buffer)
        }
    }

    /// Return streamer that will load file
    func streamFile(handle: NIOFileHandle, region: FileRegion, context: HBRequest.Context) -> EventLoopFuture<HBResponseBody> {
        let fileStreamer = FileStreamer(
            handle: handle,
            fileRegion: region,
            fileIO: self.fileIO,
            chunkSize: self.chunkSize,
            allocator: context.allocator
        )
        return context.eventLoop.makeSucceededFuture(.stream(fileStreamer))
    }

    /// write byte buffer to file
    func writeFile(buffer: ByteBuffer, handle: NIOFileHandle, on eventLoop: EventLoop) -> EventLoopFuture<Void> {
        return self.fileIO.write(fileHandle: handle, buffer: buffer, eventLoop: eventLoop)
    }

    /// write output of streamer to file
    func writeFile(stream: HBRequestBodyStreamer, handle: NIOFileHandle, on eventLoop: EventLoop) -> EventLoopFuture<Void> {
        return stream.consumeAll(on: eventLoop) { buffer in
            return self.fileIO.write(fileHandle: handle, buffer: buffer, eventLoop: eventLoop)
        }
    }

    /// class used to stream files
    class FileStreamer: HBResponseBodyStreamer {
        let chunkSize: Int
        let handle: NIOFileHandle
        var fileOffset: Int
        let endOffset: Int
        let fileIO: NonBlockingFileIO
        let allocator: ByteBufferAllocator

        init(handle: NIOFileHandle, fileRegion: FileRegion, fileIO: NonBlockingFileIO, chunkSize: Int, allocator: ByteBufferAllocator) {
            self.handle = handle
            self.fileOffset = fileRegion.readerIndex
            self.endOffset = fileRegion.endIndex
            self.fileIO = fileIO
            self.chunkSize = chunkSize
            self.allocator = allocator
        }

        func read(on eventLoop: EventLoop) -> EventLoopFuture<HBResponseBody.StreamResult> {
            let bytesLeft = self.endOffset - self.fileOffset
            let bytesToRead = min(self.chunkSize, bytesLeft)
            if bytesToRead > 0 {
                let fileOffsetToRead = self.fileOffset
                self.fileOffset += bytesToRead
                return self.fileIO.read(fileHandle: self.handle, fromOffset: Int64(fileOffsetToRead), byteCount: bytesToRead, allocator: self.allocator, eventLoop: eventLoop)
                    .map { .byteBuffer($0) }
                    .flatMapErrorThrowing { error in
                        // close handle on error being returned
                        try? self.handle.close()
                        throw error
                    }
            } else {
                // close handle now streamer has finished
                try? self.handle.close()
                return eventLoop.makeSucceededFuture(.end)
            }
        }
    }
}
