import NIO

public class RequestBody {
    enum State {
        case loading(EventLoopPromise<ByteBuffer?>)
        case loaded(ByteBuffer?)
    }
    let eventLoop: EventLoop
    var state: State

    public init(eventLoop: EventLoop) {
        self.eventLoop = eventLoop
        self.state = .loading(eventLoop.makePromise())
    }

    public func feed(_ buffer: ByteBuffer?) {
        switch state {
        case .loading(let promise):
            promise.succeed(buffer)
        case .loaded:
            preconditionFailure("Cannot feed ByteBuffers to already loaded request body")
        }
    }

    public func collect() -> EventLoopFuture<ByteBuffer?> {
        switch state {
        case .loading(let promise):
            return promise.futureResult.map { self.state = .loaded($0); return $0 }
        case .loaded(let buffer):
            return eventLoop.makeSucceededFuture(buffer)
        }
    }

    public var buffer: ByteBuffer? {
        switch state {
        case .loading:
            preconditionFailure("Request body has not been collected")
        case .loaded(let buffer):
            return buffer
        }
    }
}
