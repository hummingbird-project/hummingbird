import Hummingbird
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
    public func loadFile(for request: HBRequest, path: String) -> EventLoopFuture<HBResponse> {
        return self.fileIO.openFile(path: path, eventLoop: request.eventLoop).flatMap { handle, region in
            request.logger.debug("[FileIO] GET", metadata: ["file": .string(path)])
            let futureResponse: EventLoopFuture<HBResponse>
            if region.readableBytes > self.chunkSize {
                futureResponse = streamFile(for: request, handle: handle, region: region)
            } else {
                futureResponse = loadFile(for: request, handle: handle, region: region)
            }
            return futureResponse
        }.flatMapErrorThrowing { _ in
            throw HBHTTPError(.notFound)
        }
    }

    func loadFile(for request: HBRequest, handle: NIOFileHandle, region: FileRegion) -> EventLoopFuture<HBResponse> {
        return self.fileIO.read(fileHandle: handle, byteCount: region.readableBytes, allocator: request.allocator, eventLoop: request.eventLoop).map { buffer in
            return HBResponse(status: .ok, headers: [:], body: .byteBuffer(buffer))
        }
        .always { _ in
            try? handle.close()
        }
    }

    func streamFile(for request: HBRequest, handle: NIOFileHandle, region: FileRegion) -> EventLoopFuture<HBResponse> {
        let fileStreamer = FileStreamer(
            handle: handle,
            fileSize: region.readableBytes,
            fileIO: self.fileIO,
            chunkSize: self.chunkSize,
            allocator: request.allocator
        )
        let response = HBResponse(status: .ok, headers: [:], body: .stream(fileStreamer))
        return request.eventLoop.makeSucceededFuture(response)
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
            } else {
                try? self.handle.close()
                return eventLoop.makeSucceededFuture(.end)
            }
        }
    }
}
