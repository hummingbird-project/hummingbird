import NIO
import NIOHTTP1

/// Channel handler for decoding HTTP parts into a HTTP request
final class HTTPDecodeHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias InboundOut = Request

    enum State {
        case idle
        case head(HTTPRequestHead)
        case body(RequestBodyStreamer)
        case error
    }

    struct Request {
        let head: HTTPRequestHead
        let body: RequestBody
    }

    /// handler state
    var maxUploadSize: Int
    var state: State

    init(maxUploadSize: Int) {
        self.maxUploadSize = maxUploadSize
        self.state = .idle
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let part = self.unwrapInboundIn(data)

        switch (part, state) {
        case (.head(let head), .idle):
            self.state = .head(head)

        case (.body(let part), .head(let head)):
            let streamer = RequestBodyStreamer(eventLoop: context.eventLoop, maxSize: self.maxUploadSize)
            let request = Request(head: head, body: .stream(streamer))
            streamer.feed(.byteBuffer(part))
            context.fireChannelRead(self.wrapInboundOut(request))
            self.state = .body(streamer)

        case (.body(let part), .body(let streamer)):
            streamer.feed(.byteBuffer(part))
            self.state = .body(streamer)

        case (.end, .head(let head)):
            let request = Request(head: head, body: .byteBuffer(nil))
            context.fireChannelRead(self.wrapInboundOut(request))
            self.state = .idle

        case (.end, .body(let streamer)):
            streamer.feed(.end)
            self.state = .idle

        case (.end, .error):
            self.state = .idle

        case (_, .error):
            break

        default:
            assertionFailure("Should not get here")
            context.close(promise: nil)
        }
    }

    func channelReadComplete(context: ChannelHandlerContext) {
        context.flush()
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        switch state {
        case .body(let streamer):
            // request has already been forwarded to next hander have to pass error via streamer
            streamer.feed(.error(error))
            // only set state to error if already streaming a request body. Don't want to feed
            // additional ByteBuffers to streamer if error has been set
            self.state = .error
        default:
            context.fireErrorCaught(error)
        }
    }
}

/// Channel handler for encoding Response into HTTP parts
final class HTTPEncodeHandler: ChannelOutboundHandler {
    typealias OutboundIn = Response
    typealias OutboundOut = HTTPServerResponsePart

    struct Response {
        let head: HTTPResponseHead
        let body: ResponseBody
    }

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let response = self.unwrapOutboundIn(data)

        // add content-length header
        var head = response.head
        if case .byteBuffer(let buffer) = response.body {
            head.headers.replaceOrAdd(name: "content-length", value: buffer.readableBytes.description)
        }
        context.write(self.wrapOutboundOut(.head(head)), promise: nil)
        switch response.body {
        case .byteBuffer(let buffer):
            context.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
            context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: promise)
        case .stream(let streamer):
            streamer.write(on: context.eventLoop) { buffer in
                context.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
            }
            .whenComplete { result in
                switch result {
                case .failure:
                    // not sure what do write when result is an error, just closing channel for the moment
                    context.close(promise: nil)
                case .success:
                    context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: promise)
                }
            }
        case .empty:
            context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: promise)
        }
    }
}
