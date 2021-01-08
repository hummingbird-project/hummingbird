import HummingBird
import NIO

let app = Application()

app.router.add("/", method: .GET) { request -> EventLoopFuture<ByteBuffer> in
    let response = request.allocator.buffer(string: "This is a test")
    return request.eventLoop.makeSucceededFuture(response)
}

app.router.add("/hello", method: .GET) { request -> EventLoopFuture<ByteBuffer> in
    let response = request.allocator.buffer(string: "Hello")
    return request.eventLoop.makeSucceededFuture(response)
}

app.serve()
