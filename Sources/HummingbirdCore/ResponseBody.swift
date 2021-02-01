import NIO

/// Response body
public enum HBResponseBody {
    /// ByteBuffer
    case byteBuffer(ByteBuffer)
    /// Streamer object supplying byte buffers
    case stream(HBResponseBodyStreamer)
    /// Empty body
    case empty

    public static func streamCallback(_ closure: @escaping (EventLoop) -> EventLoopFuture<HBResponseBody.StreamResult>) -> Self {
        .stream(ResponseBodyStreamerCallback(closure: closure))
    }

    /// response body streamer result. Either a ByteBuffer or the end of the stream
    public enum StreamResult {
        case byteBuffer(ByteBuffer)
        case end
    }
}

/// Object supplying bytebuffers for a response body
public protocol HBResponseBodyStreamer {
    func read(on eventLoop: EventLoop) -> EventLoopFuture<HBResponseBody.StreamResult>
}

extension HBResponseBodyStreamer {
    /// Call closure for every ByteBuffer streamed
    /// - Returns: When everything has been streamed
    func write(on eventLoop: EventLoop, _ writeCallback: @escaping (ByteBuffer) -> Void) -> EventLoopFuture<Void> {
        let promise = eventLoop.makePromise(of: Void.self)
        func _stream() {
            self.read(on: eventLoop).whenComplete { result in
                switch result {
                case .success(.byteBuffer(let buffer)):
                    writeCallback(buffer)
                    _stream()
                case .success(.end):
                    promise.succeed(())
                case .failure(let error):
                    promise.fail(error)
                }
            }
        }
        _stream()
        return promise.futureResult
    }
}

struct ResponseBodyStreamerCallback: HBResponseBodyStreamer {
    let closure: (EventLoop) -> EventLoopFuture<HBResponseBody.StreamResult>
    func read(on eventLoop: EventLoop) -> EventLoopFuture<HBResponseBody.StreamResult> {
        return self.closure(eventLoop)
    }
}
