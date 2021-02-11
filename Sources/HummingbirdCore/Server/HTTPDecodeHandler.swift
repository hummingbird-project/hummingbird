import NIO
import NIOHTTP1

/// Channel handler for decoding HTTP parts into a HTTP request
final class HBHTTPDecodeHandler: ChannelDuplexHandler {
    public typealias InboundIn = HTTPServerRequestPart
    public typealias InboundOut = HBHTTPRequest
    public typealias OutboundIn = Never
    public typealias OutboundOut = HTTPServerResponsePart

    enum State {
        case idle
        case head(HTTPRequestHead)
        case body(HBRequestBodyStreamer)
        case error
    }

    let maxUploadSize: Int

    /// handler state
    var state: State

    init(configuration: HBHTTPServer.Configuration) {
        self.maxUploadSize = configuration.maxUploadSize
        self.state = .idle
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let part = self.unwrapInboundIn(data)

        switch (part, self.state) {
        case (.head(let head), .idle):
            self.state = .head(head)

        case (.body(let part), .head(let head)):
            let streamer = HBRequestBodyStreamer(eventLoop: context.eventLoop, maxSize: self.maxUploadSize)
            let request = HBHTTPRequest(head: head, body: .stream(streamer))
            streamer.feed(.byteBuffer(part))
            context.fireChannelRead(self.wrapInboundOut(request))
            self.state = .body(streamer)

        case (.body(let part), .body(let streamer)):
            streamer.feed(.byteBuffer(part))
            self.state = .body(streamer)

        case (.end, .head(let head)):
            let request = HBHTTPRequest(head: head, body: .byteBuffer(nil))
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

    func read(context: ChannelHandlerContext) {
        context.read()
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        switch self.state {
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

