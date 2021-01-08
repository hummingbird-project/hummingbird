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

    struct Response {
        let head: HTTPResponseHead
        let body: ByteBuffer?
    }

    /// handler state
    var state: State
    var process: (Request, ChannelHandlerContext) -> EventLoopFuture<Response>

    init(_ process: @escaping (Request, ChannelHandlerContext) -> EventLoopFuture<Response>) {
        self.state = .idle
        self.process = process
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let part = self.unwrapInboundIn(data)
        switch (part, state) {
        case (.head(let head), .idle):
            state = .head(head)
        case (.body(let part), .head(let head)):
            state = .body(head, part)
        case (.body(var part), .body(let head, var buffer)):
            buffer.writeBuffer(&part)
            state = .body(head, buffer)
        case (.end, .head(let head)):
            let request = Request(head: head, body: nil, context: context)
            process(request, context).whenComplete { result in
                switch result {
                case .failure:
                    context.write(self.wrapOutboundOut(
                                    .head(.init(version: .init(major: 1, minor: 1), status: .internalServerError ))),
                                  promise: nil)
                    context.write(self.wrapOutboundOut(.end(HTTPHeaders())), promise: nil)
                case .success(let value):
                    context.write(self.wrapOutboundOut(.head(value.head)), promise: nil)
                    if let body = value.body {
                        context.write(self.wrapOutboundOut(.body(.byteBuffer(body))), promise: nil)
                    }
                    context.write(self.wrapOutboundOut(.end(HTTPHeaders())), promise: nil)
                }
            }
        default:
            break
        }
    }

    func channelReadComplete(context: ChannelHandlerContext) {
        context.flush()
    }
}
