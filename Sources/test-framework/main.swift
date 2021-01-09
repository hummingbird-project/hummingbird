import Foundation
import HBJSON
import HBXML
import HummingBird
import NIO
import NIOHTTP1

struct ErrorMiddleware: Middleware {
    func apply(to request: Request, next: Responder) -> EventLoopFuture<Response> {
        return next.apply(to: request).flatMapErrorThrowing { error in
            Response(status: .badRequest, headers: [:], body: request.allocator.buffer(string: "ERROR!"))
        }
    }
}

struct TestMiddleware: Middleware {
    func apply(to request: Request, next: Responder) -> EventLoopFuture<Response> {
        return next.apply(to: request).map { response in
            if var buffer = response.body {
                buffer.writeString("\ntest\n")
                return Response(status: .ok, headers: response.headers, body: buffer)
            }
            return response
        }
    }
}
struct User: Codable {
    let name: String
    let age: Int
}

let app = Application()
app.encoder = JSONEncoder()
app.decoder = JSONDecoder()

app.middlewares.add(ErrorMiddleware())

app.router.get("/") { request -> EventLoopFuture<ByteBuffer> in
    let response = request.allocator.buffer(string: "This is a test")
    return request.eventLoop.makeSucceededFuture(response)
}

app.router.get("/hello") { request -> EventLoopFuture<ByteBuffer> in
    let response = request.allocator.buffer(string: "Hello")
    return request.eventLoop.makeSucceededFuture(response)
}

app.router.get("/user") { request -> EventLoopFuture<User> in
    let name = request.uri.queryParameters["name"] ?? "Unknown"
    return request.eventLoop.makeSucceededFuture(.init(name: String(name), age: 42))
}

app.router.put("/user") { request -> EventLoopFuture<String> in
    guard let user = try? request.decode(as: User.self) else { return request.eventLoop.makeFailedFuture(HTTPError(.badRequest)) }
    return request.eventLoop.makeSucceededFuture("ok")
}

let group = app.router.group()
    .add(middleware: TestMiddleware())

group.get("/test") { request -> EventLoopFuture<ByteBuffer> in
    let response = request.allocator.buffer(string: "GoodBye")
    return request.eventLoop.makeSucceededFuture(response)
}

app.serve()
