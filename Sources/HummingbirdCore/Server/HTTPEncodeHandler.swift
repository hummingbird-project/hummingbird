import NIO
import NIOHTTP1

/// Channel handler for encoding Response into HTTP parts
final class HBHTTPEncodeHandler: ChannelOutboundHandler {
    typealias OutboundIn = HBHTTPResponse
    typealias OutboundOut = HTTPServerResponsePart

    let serverName: String?

    init(configuration: HBHTTPServer.Configuration) {
        self.serverName = configuration.serverName
    }

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let response = self.unwrapOutboundIn(data)

        // add content-length header
        var head = response.head
        if case .byteBuffer(let buffer) = response.body {
            head.headers.replaceOrAdd(name: "content-length", value: buffer.readableBytes.description)
        }
        // server name
        if let serverName = self.serverName {
            head.headers.replaceOrAdd(name: "server", value: serverName)
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
                    // not sure what do write when result is an error, sending .end and closing channel for the moment
                    context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: promise)
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
