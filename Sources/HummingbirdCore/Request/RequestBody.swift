import NIO
import NIOConcurrencyHelpers

/// Request Body. Either a ByteBuffer or a ByteBuffer streamer
public enum HBRequestBody {
    /// Static ByteBuffer
    case byteBuffer(ByteBuffer?)
    /// ByteBuffer streamer
    case stream(HBRequestBodyStreamer)

    /// Return as ByteBuffer
    public var buffer: ByteBuffer? {
        switch self {
        case .byteBuffer(let buffer):
            return buffer
        default:
            preconditionFailure("Cannot get buffer on streaming RequestBody")
        }
    }

    /// Return as streamer if it is a streamer
    public var stream: HBRequestBodyStreamer {
        switch self {
        case .stream(let streamer):
            return streamer
        default:
            preconditionFailure("Cannot get stream from already consumed stream")
        }
    }

    /// Provide body as a single ByteBuffer
    /// - Parameter eventLoop: EventLoop to use
    /// - Returns: EventLoopFuture that will be fulfilled with ByteBuffer. If no body is include then return `nil`
    public func consumeBody(on eventLoop: EventLoop) -> EventLoopFuture<ByteBuffer?> {
        switch self {
        case .byteBuffer(let buffer):
            return eventLoop.makeSucceededFuture(buffer)
        case .stream(let streamer):
            return streamer.consumeAll().hop(to: eventLoop)
        }
    }

    /// Return as streaming body. Can convert empty body to a streamer
    /// - Parameter eventLoop: EventLoop to use
    /// - Returns: streaming body
    public func streamBody(on eventLoop: EventLoop) -> HBRequestBodyStreamer {
        switch self {
        case .byteBuffer(let buffer):
            precondition(buffer == nil, "Cannot call streamBody on already loaded Body")
            let streamer = HBRequestBodyStreamer(eventLoop: eventLoop, maxSize: 0)
            streamer.feed(.end)
            return streamer
        case .stream(let streamer):
            return streamer
        }
    }
}

/// Request body streamer. `HBHTTPDecodeHandler` feeds this with ByteBuffers while the Router consumes them
public class HBRequestBodyStreamer {
    public enum StreamerError: Swift.Error {
        case bodyDropped
    }

    /// Values we can feed the streamer with
    public enum FeedInput {
        case byteBuffer(ByteBuffer)
        case error(Error)
        case end
    }

    /// Values returned when we consume the contents of the streamer
    public enum ConsumeOutput {
        case byteBuffer(ByteBuffer)
        case end
    }

    /// Queue of promises for each ByteBuffer fed to the streamer. Last entry is always waiting for the next buffer or end tag
    var queue: CircularBuffer<EventLoopPromise<ConsumeOutput>>
    /// EventLoop everything is running on
    let eventLoop: EventLoop
    /// called every time a ByteBuffer is consumed
    var onConsume: ((HBRequestBodyStreamer) -> Void)?
    /// maximum allowed size to upload
    let maxSize: Int
    /// current size in memory
    var currentSize: Int
    /// bytes fed to streamer so far
    var sizeFed: Int
    /// has request streamer data been dropped
    var dropped: Bool

    init(eventLoop: EventLoop, maxSize: Int) {
        self.queue = .init(initialCapacity: 8)
        self.queue.append(eventLoop.makePromise())
        self.eventLoop = eventLoop
        self.sizeFed = 0
        self.currentSize = 0
        self.maxSize = maxSize
        self.onConsume = nil
        self.dropped = false
    }

    /// Feed a ByteBuffer to the request
    /// - Parameter result: Bytebuffer or end tag
    func feed(_ result: FeedInput) {
        self.eventLoop.assertInEventLoop()
        guard self.dropped == false else { return }

        // queue most have at least one promise on it, or something has gone wrong
        assert(self.queue.last != nil)
        let promise = self.queue.last!

        switch result {
        case .byteBuffer(let byteBuffer):
            self.queue.append(self.eventLoop.makePromise())

            self.sizeFed += byteBuffer.readableBytes
            self.currentSize += byteBuffer.readableBytes

            if self.sizeFed > self.maxSize {
                promise.fail(HBHTTPError(.payloadTooLarge))
            } else {
                promise.succeed(.byteBuffer(byteBuffer))
            }
        case .error(let error):
            promise.fail(error)
        case .end:
            promise.succeed(.end)
        }
    }

    /// Consume what has been fed to the request
    /// - Parameter eventLoop: EventLoop to return future on
    /// - Returns: Returns an EventLoopFuture that will be fulfilled with array of ByteBuffers that has so far been fed to th request body
    ///     and whether we have consumed everything
    public func consume(on eventLoop: EventLoop) -> EventLoopFuture<ConsumeOutput> {
        self.consume().hop(to: eventLoop)
    }

    /// Consume the request body, calling `process` on each buffer until you receive an end tag
    /// - Returns: EventLoopFuture that will be fulfilled with the full ByteBuffer of the Request
    /// - Parameters:
    ///   - eventLoop: EventLoop to run on
    ///   - process: Closure to call to process ByteBuffer
    public func consumeAll(on eventLoop: EventLoop, _ process: @escaping (ByteBuffer) -> EventLoopFuture<Void>) -> EventLoopFuture<Void> {
        let promise = self.eventLoop.makePromise(of: Void.self)
        func _consumeAll() {
            self.consume(on: eventLoop).map { output in
                switch output {
                case .byteBuffer(let buffer):
                    process(buffer).whenComplete { result in
                        switch result {
                        case .failure(let error):
                            promise.fail(error)
                        case .success:
                            _consumeAll()
                        }
                    }

                case .end:
                    promise.succeed(())
                }
            }
            .cascadeFailure(to: promise)
        }
        _consumeAll()
        return promise.futureResult
    }

    /// Drop the remains of the data to be streamed as we are not interested in it anymore.
    ///
    /// This is required to be called as soon as we know we do not need the contents of the
    /// `HBRequestBodyStreamer`. If we do not drop the data then it can stall the loading
    /// of the next HTTP request because the back pressure will still consider there to be too
    /// much data currently being processed
    public func drop() {
        self.eventLoop.assertInEventLoop()
        // empty the queue and succeed each promise
        guard self.queue.last != nil else { return }
        while let promise = self.queue.popFirst() {
            promise.fail(StreamerError.bodyDropped)
        }
        self.currentSize = 0
        self.dropped = true
        self.onConsume?(self)
    }

    /// Consume what has been fed to the request
    /// - Returns: Returns an EventLoopFuture that will be fulfilled with array of ByteBuffers that has so far been fed to the request body
    ///     and whether we have consumed an end tag
    func consume() -> EventLoopFuture<ConsumeOutput> {
        assert(self.queue.first != nil)
        let promise = self.queue.first!
        return promise.futureResult.map { result in
            _ = self.queue.popFirst()

            switch result {
            case .byteBuffer(let buffer):
                self.currentSize -= buffer.readableBytes
            case .end:
                assert(self.currentSize == 0)
            }
            self.onConsume?(self)
            return result
        }
    }

    /// Consume the request body until you receive an end tag
    /// - Returns: EventLoopFuture that will be fulfilled with the full ByteBuffer of the Request
    func consumeAll() -> EventLoopFuture<ByteBuffer?> {
        let promise = self.eventLoop.makePromise(of: ByteBuffer?.self)
        var completeBuffer: ByteBuffer?
        func _consumeAll() {
            self.consume().map { output in
                switch output {
                case .byteBuffer(var buffer):
                    if completeBuffer != nil {
                        completeBuffer!.writeBuffer(&buffer)
                    } else {
                        completeBuffer = buffer
                    }
                    _consumeAll()

                case .end:
                    promise.succeed(completeBuffer)
                }
            }
            .cascadeFailure(to: promise)
        }
        _consumeAll()
        return promise.futureResult
    }
}
