import NIO
import NIOConcurrencyHelpers

/// Request Body. Either a ByteBuffer or a streaming of ByteBuffer
public enum HBRequestBody {
    case byteBuffer(ByteBuffer?)
    case stream(HBRequestBodyStreamer)

    public var buffer: ByteBuffer? {
        switch self {
        case .byteBuffer(let buffer):
            return buffer
        default:
            preconditionFailure("Cannot get buffer on streaming RequestBody")
        }
    }

    public var stream: HBRequestBodyStreamer {
        switch self {
        case .stream(let streamer):
            return streamer
        default:
            preconditionFailure("Cannot get stream from already consumed stream")
        }
    }

    public func consumeBody(on eventLoop: EventLoop) -> EventLoopFuture<ByteBuffer?> {
        switch self {
        case .byteBuffer(let buffer):
            return eventLoop.makeSucceededFuture(buffer)
        case .stream(let streamer):
            return streamer.consumeAll().hop(to: eventLoop)
        }
    }

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

/// Request body streamer. HTTPInHandler feeds this with ByteBuffers while the Router consumes them
public class HBRequestBodyStreamer {
    public enum FeedInput {
        case byteBuffer(ByteBuffer)
        case error(Error)
        case end
    }
    public enum ConsumeOutput {
        case byteBuffers([ByteBuffer])
        case end
    }

    var entries: [ByteBuffer]
    let eventLoop: EventLoop
    var nextPromise: EventLoopPromise<Bool>
    let maxSize: Int
    var sizeFed: Int

    init(eventLoop: EventLoop, maxSize: Int) {
        self.entries = []
        self.eventLoop = eventLoop
        self.nextPromise = eventLoop.makePromise()
        self.sizeFed = 0
        self.maxSize = maxSize
    }

    /// Feed a ByteBuffer to the request
    /// - Parameter result: Bytebuffer or end tag
    func feed(_ result: FeedInput) {
        switch result {
        case .byteBuffer(let byteBuffer):
            sizeFed += byteBuffer.readableBytes
            if sizeFed > maxSize {
                nextPromise.fail(HBHTTPError(.payloadTooLarge))
            } else {
                self.entries.append(byteBuffer)
                nextPromise.succeed(false)
            }
        case .error(let error):
            nextPromise.fail(error)
        case .end:
            nextPromise.succeed(true)
        }
    }

    /// Consume what has been fed to the request
    /// - Parameter eventLoop: EventLoop to return future on
    /// - Returns: Returns an EventLoopFuture that will be fulfilled with array of ByteBuffers that has so far been fed to th request body
    ///     and whether we have consumed everything
    public func consume(on eventLoop: EventLoop) -> EventLoopFuture<ConsumeOutput> {
        consume().hop(to: eventLoop)
    }

    /// Consume what has been fed to the request
    /// - Returns: Returns an EventLoopFuture that will be fulfilled with array of ByteBuffers that has so far been fed to the request body
    ///     and whether we have consumed an end tag
    func consume() -> EventLoopFuture<ConsumeOutput> {
        nextPromise.futureResult.map { finished in
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
        }
    }

    /// Consume the request body until you receive an end tag
    /// - Returns: EventLoopFuture that will be fulfilled with the full ByteBuffer of the Request
    func consumeAll() -> EventLoopFuture<ByteBuffer?> {
        let promise = self.eventLoop.makePromise(of: ByteBuffer?.self)
        var buffer: ByteBuffer? = nil
        func _consumeAll() {
            consume().map { output in
                switch output {
                case .byteBuffers(let buffers):
                    var buffersToAdd: ArraySlice<ByteBuffer>
                    if buffer == nil, let firstBuffer = buffers.first {
                        buffer = firstBuffer
                        buffersToAdd = buffers.dropFirst()
                    } else {
                        buffersToAdd = buffers[...]
                    }
                    for var b in buffersToAdd {
                        buffer!.writeBuffer(&b)
                    }
                    _consumeAll()
                    
                case .end:
                    promise.succeed(buffer)
                }
            }
            .cascadeFailure(to: promise)
        }
        _consumeAll()
        return promise.futureResult
    }
}
