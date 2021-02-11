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

    var entries: CircularBuffer<ByteBuffer>
    let eventLoop: EventLoop
    var nextPromise: EventLoopPromise<Bool>
    /// maximum allowed size to upload
    let maxSize: Int
    /// current size in memory
    var currentSize: Int
    /// bytes fed to streamer so far
    var sizeFed: Int

    init(eventLoop: EventLoop, maxSize: Int) {
        self.entries = .init(initialCapacity: 8)
        self.eventLoop = eventLoop
        self.nextPromise = eventLoop.makePromise()
        self.sizeFed = 0
        self.currentSize = 0
        self.maxSize = maxSize
    }

    /// Feed a ByteBuffer to the request
    /// - Parameter result: Bytebuffer or end tag
    func feed(_ result: FeedInput) {
        switch result {
        case .byteBuffer(let byteBuffer):
            self.sizeFed += byteBuffer.readableBytes
            self.currentSize += byteBuffer.readableBytes
            if self.sizeFed > self.maxSize {
                self.nextPromise.fail(HBHTTPError(.payloadTooLarge))
            } else {
                self.entries.append(byteBuffer)
                self.nextPromise.succeed(false)
            }
        case .error(let error):
            self.nextPromise.fail(error)
        case .end:
            self.nextPromise.succeed(true)
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
        self.nextPromise.futureResult.map { finished in
            if let entry = self.entries.popFirst() {
                if self.entries.count == 0 {
                    self.nextPromise = self.eventLoop.makePromise()
                }
                if finished {
                    self.nextPromise.succeed(true)
                }
                return .byteBuffers(entry)
            } else {
                return .end
            }
        }
/*        self.nextPromise.futureResult.map { finished in
            let entries = self.entries
            self.entries = []
            if entries.count > 0 {
                self.nextPromise = self.eventLoop.makePromise()
                if finished {
                    self.nextPromise.succeed(true)
                }
                return .byteBuffers(entries)
            } else {
                return .end
            }
        }*/
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
