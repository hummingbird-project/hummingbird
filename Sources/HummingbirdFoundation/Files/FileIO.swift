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
    public func headFile(for request: HBRequest, path: String) -> EventLoopFuture<HBResponse> {
        return self.fileIO.openFile(path: path, eventLoop: request.eventLoop).flatMap { handle, region in
            request.logger.debug("[FileIO] HEAD", metadata: ["file": .string(path)])
            let headers: HTTPHeaders = ["content-length": region.readableBytes.description]
            let response = HBResponse(status: .ok, headers: headers, body: .empty)
            try? handle.close()
            return request.eventLoop.makeSucceededFuture(response)
        }.flatMapErrorThrowing { _ in
            throw HBHTTPError(.notFound)
        }
    }

    /// Load file and pass to response
    ///
    /// Depending on the file size this will return either a response containing a ByteBuffer or a stream that will provide the
    /// file in chunks.
    /// - Parameters:
    ///   - request: request for file
    ///   - path: System file path
    /// - Returns: Response include file
    public func loadFile(for request: HBRequest, path: String) -> EventLoopFuture<HBResponseBody> {
        return self.fileIO.openFile(path: path, eventLoop: request.eventLoop).flatMap { handle, region in
            request.logger.debug("[FileIO] GET", metadata: ["file": .string(path)])
            let futureResult: EventLoopFuture<HBResponseBody>
            if region.readableBytes > self.chunkSize {
                futureResult = streamFile(for: request, handle: handle, region: region)
            } else {
                futureResult = loadFile(for: request, handle: handle, region: region)
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
    public func writeFile(contents: HBRequestBody, path: String, on eventLoop: EventLoop, logger: Logger) -> EventLoopFuture<Void> {
        return self.fileIO.openFile(path: path, mode: .write, flags: .allowFileCreation(), eventLoop: eventLoop).flatMap { handle in
            logger.debug("[FileIO] PUT", metadata: ["file": .string(path)])
            let futureResult: EventLoopFuture<Void>
            switch contents {
            case .byteBuffer(let buffer):
                guard let buffer = buffer else { return eventLoop.makeSucceededFuture(()) }
                futureResult = writeFile(buffer: buffer, handle: handle, on: eventLoop)
            case .stream(let streamer):
                futureResult = writeFile(stream: streamer, handle: handle, on: eventLoop)
            }
            futureResult.whenComplete { _ in
                try? handle.close()
            }
            return futureResult
        }
    }

    /// Load file as ByteBuffer
    func loadFile(for request: HBRequest, handle: NIOFileHandle, region: FileRegion) -> EventLoopFuture<HBResponseBody> {
        return self.fileIO.read(fileHandle: handle, byteCount: region.readableBytes, allocator: request.allocator, eventLoop: request.eventLoop).map { buffer in
            return .byteBuffer(buffer)
        }
    }

    /// Return streamer that will load file
    func streamFile(for request: HBRequest, handle: NIOFileHandle, region: FileRegion) -> EventLoopFuture<HBResponseBody> {
        let fileStreamer = FileStreamer(
            handle: handle,
            fileSize: region.readableBytes,
            fileIO: self.fileIO,
            chunkSize: self.chunkSize,
            allocator: request.allocator
        )
        return request.eventLoop.makeSucceededFuture(.stream(fileStreamer))
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
        var handle: NIOFileHandle
        var bytesLeft: Int
        var fileIO: NonBlockingFileIO
        var allocator: ByteBufferAllocator

        init(handle: NIOFileHandle, fileSize: Int, fileIO: NonBlockingFileIO, chunkSize: Int, allocator: ByteBufferAllocator) {
            self.handle = handle
            self.bytesLeft = fileSize
            self.fileIO = fileIO
            self.chunkSize = chunkSize
            self.allocator = allocator
        }

        func read(on eventLoop: EventLoop) -> EventLoopFuture<HBResponseBody.StreamResult> {
            let bytesToRead = min(self.chunkSize, self.bytesLeft)
            if bytesToRead > 0 {
                self.bytesLeft -= bytesToRead
                return self.fileIO.read(fileHandle: self.handle, byteCount: bytesToRead, allocator: self.allocator, eventLoop: eventLoop)
                    .map { .byteBuffer($0) }
                    .flatMapErrorThrowing { error in
                        // close handle on error being returned
                        try? self.handle.close()
                        throw error
                    }
            } else {
                // close handle now streamer has finished
                try? handle.close()
                return eventLoop.makeSucceededFuture(.end)
            }
        }
    }
}
