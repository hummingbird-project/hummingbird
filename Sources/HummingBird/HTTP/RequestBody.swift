import NIO
import NIOConcurrencyHelpers

/// Request Body. Either a ByteBuffer or a streaming of ByteBuffer
public enum RequestBody {
    case byteBuffer(ByteBuffer?)
    case stream(RequestBodyStreamer)

    public var buffer: ByteBuffer? {
        switch self {
        case .byteBuffer(let buffer):
            return buffer
        default:
            preconditionFailure("Cannot get buffer on streaming RequestBody")
        }
    }

    public var stream: RequestBodyStreamer {
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
}

/// Request body streamer. HTTPInHandler feeds this with ByteBuffers while the Router consumes them
public class RequestBodyStreamer {
    public enum StreamResult {
        case byteBuffer(ByteBuffer)
        case end
    }

    var entries: [ByteBuffer]
    let eventLoop: EventLoop
    var nextPromise: EventLoopPromise<Bool>

    init(eventLoop: EventLoop) {
        self.entries = []
        self.eventLoop = eventLoop
        self.nextPromise = eventLoop.makePromise()
    }

    /// Feed a ByteBuffer to the request
    /// - Parameter result: Bytebuffer or end tag
    func feed(_ result: StreamResult) {
        switch result {
        case .byteBuffer(let byteBuffer):
            self.entries.append(byteBuffer)
            nextPromise.succeed(false)
        case .end:
            nextPromise.succeed(true)
        }
    }

    /// Consume what has been fed to the request
    /// - Parameter eventLoop: EventLoop to return future on
    /// - Returns: Returns an EventLoopFuture that will be fulfilled with array of ByteBuffers that has so far been fed to th request body
    ///     and whether we have consumed everything
    public func consume(on eventLoop: EventLoop) -> EventLoopFuture<(Bool, [ByteBuffer])> {
        nextPromise.futureResult.map { finished in
            let entries = self.entries
            self.entries = []
            if !finished {
                self.nextPromise = self.eventLoop.makePromise()
            }
            return (finished, entries)
        }.hop(to: eventLoop)
    }

    /// Consume what has been fed to the request
    /// - Returns: Returns an EventLoopFuture that will be fulfilled with array of ByteBuffers that has so far been fed to the request body
    ///     and whether we have consumed an end tag
    func consume() -> EventLoopFuture<(Bool, [ByteBuffer])> {
        nextPromise.futureResult.map { finished in
            let entries = self.entries
            self.entries = []
            if !finished {
                self.nextPromise = self.eventLoop.makePromise()
            }
            return (finished, entries)
        }
    }

    /// Consume the request body until you receive an end tag
    /// - Returns: EventLoopFuture that will be fulfilled with the full ByteBuffer of the Request
    func consumeAll() -> EventLoopFuture<ByteBuffer?> {
        let promise = self.eventLoop.makePromise(of: ByteBuffer?.self)
        var buffer: ByteBuffer? = nil
        func _consumeAll() {
            consume().map { (finished, buffers) in
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
                if !finished {
                    _consumeAll()
                } else {
                    promise.succeed(buffer)
                }
            }
            .cascadeFailure(to: promise)
        }
        _consumeAll()
        return promise.futureResult
    }
}
