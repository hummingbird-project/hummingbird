import NIO

final class HTTPInHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias InboundOut = Request

    enum State {
        case idle
        case head(HTTPRequestHead)
        case body(HTTPRequestHead, ByteBuffer)
    }

    struct Request {
        let head: HTTPRequestHead
        let body: ByteBuffer?
        let context: ChannelHandlerContext
    }

    /// handler state
    var state: State

    init() {
        self.state = .idle
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let part = self.unwrapInboundIn(data)
    
        switch (part, self.state) {
        case (.head(let head), .idle):
            state = .head(head)
        case (.body(let part), .head(let head)):
            state = .body(head, part)
        case (.body(var part), .body(let head, var buffer)):
            buffer.writeBuffer(&part)
            state = .body(head, buffer)
        case (.end, .head(let head)):
            let request = Request(head: head, body: nil, context: context)
            context.fireChannelRead(self.wrapInboundOut(request))
            state = .idle
        case (.end, .body(let head, let body)):
            let request = Request(head: head, body: body, context: context)
            context.fireChannelRead(self.wrapInboundOut(request))
            state = .idle
        default:
            assert(false)
            context.close(promise: nil)
            break
        }
    }
    
   func channelReadComplete(context: ChannelHandlerContext) {
        context.flush()
    }
}


final class HTTPOutHandler: ChannelOutboundHandler {
    typealias OutboundIn = Response
    typealias OutboundOut = HTTPServerResponsePart
    
    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let response = self.unwrapOutboundIn(data)
        
        // add content-length header
        var headers = response.headers
        if case .byteBuffer(let buffer) = response.body {
            headers.replaceOrAdd(name: "content-length", value: buffer.readableBytes.description)
        }
        let head = HTTPResponseHead(version: .init(major: 1, minor: 1), status: response.status, headers: headers)
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

