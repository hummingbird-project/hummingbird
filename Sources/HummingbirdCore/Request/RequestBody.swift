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
    /// Values we can feed the streamer with
    public enum FeedInput {
        case byteBuffer(ByteBuffer)
        case error(Error)
        case end
    }

    /// Values returned when we consume the contents of the streamer
    public enum ConsumeOutput {
        case byteBuffers(ByteBuffer)
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

    init(eventLoop: EventLoop, maxSize: Int) {
        self.queue = .init(initialCapacity: 8)
        self.queue.append(eventLoop.makePromise())
        self.eventLoop = eventLoop
        self.sizeFed = 0
        self.currentSize = 0
        self.maxSize = maxSize
        self.onConsume = nil
    }

    /// Feed a ByteBuffer to the request
    /// - Parameter result: Bytebuffer or end tag
    func feed(_ result: FeedInput) {
        self.eventLoop.assertInEventLoop()
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
                promise.succeed(.byteBuffers(byteBuffer))
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

    /// Consume what has been fed to the request
    /// - Returns: Returns an EventLoopFuture that will be fulfilled with array of ByteBuffers that has so far been fed to the request body
    ///     and whether we have consumed an end tag
    func consume() -> EventLoopFuture<ConsumeOutput> {
        assert(self.queue.first != nil)
        let promise = self.queue.first!
        return promise.futureResult.map { result in
            _ = self.queue.popFirst()

            switch result {
            case .byteBuffers(let buffer):
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
                case .byteBuffers(var buffer):
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
