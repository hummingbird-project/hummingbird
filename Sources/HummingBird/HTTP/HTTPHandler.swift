import NIO
import NIOHTTP1

final class HTTPHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

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
    var keepAlive: Bool
    var process: (Request, ChannelHandlerContext) -> EventLoopFuture<Response>

    init(_ process: @escaping (Request, ChannelHandlerContext) -> EventLoopFuture<Response>) {
        self.state = .idle
        self.process = process
        self.keepAlive = false
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let part = self.unwrapInboundIn(data)
        switch (part, state) {
        case (.head(let head), .idle):
            state = .head(head)
            keepAlive = head.isKeepAlive
        case (.body(let part), .head(let head)):
            state = .body(head, part)
        case (.body(var part), .body(let head, var buffer)):
            buffer.writeBuffer(&part)
            state = .body(head, buffer)
        case (.end, .head(let head)):
            let request = Request(head: head, body: nil, context: context)
            process(request, context).whenComplete { result in
                self.processResult(result, context: context)
            }
        case (.end, .body(let head, let body)):
            let request = Request(head: head, body: body, context: context)
            process(request, context).whenComplete { result in
                self.processResult(result, context: context)
            }
        default:
            // shouldnt get here so just write bad request out
            context.write(self.wrapOutboundOut(
                            .head(.init(version: .init(major: 1, minor: 1), status: .badRequest))),
                          promise: nil)
            context.write(self.wrapOutboundOut(.end(HTTPHeaders())), promise: nil)
            state = .idle
        }
    }
    
    func processResult(_ result: Result<Response, Error>, context: ChannelHandlerContext) {
        switch result {
        case .failure:
            context.write(self.wrapOutboundOut(
                            .head(.init(version: .init(major: 1, minor: 1), status: .internalServerError))),
                          promise: nil)
            context.write(self.wrapOutboundOut(.end(HTTPHeaders())), promise: nil)
        case .success(let value):
            // add content-length header
            var headers = value.headers
            if case .byteBuffer(let buffer) = value.body {
                headers.replaceOrAdd(name: "content-length", value: buffer.readableBytes.description)
            }
            let head = HTTPResponseHead(version: .init(major: 1, minor: 1), status: value.status, headers: headers)
            context.write(self.wrapOutboundOut(.head(head)), promise: nil)
            switch value.body {
            case .byteBuffer(let buffer):
                context.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
                self.completeResponse(context, trailers: nil, promise: nil)
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
                        self.completeResponse(context, trailers: nil, promise: nil)
                    }
                }
            case .empty:
                self.completeResponse(context, trailers: nil, promise: nil)
            }
        }
    }

    func completeResponse(_ context: ChannelHandlerContext, trailers: HTTPHeaders?, promise: EventLoopPromise<Void>?) {
        self.state = .idle

        let promise = self.keepAlive ? promise : (promise ?? context.eventLoop.makePromise())
        if !self.keepAlive {
            promise!.futureResult.whenComplete { result in
                context.close(promise: nil)
            }
        }

        context.writeAndFlush(self.wrapOutboundOut(.end(trailers)), promise: promise)
    }

    func channelReadComplete(context: ChannelHandlerContext) {
        context.flush()
    }
}
