import Foundation
import HBFileMiddleware
import HBJSON
import HBXML
import HummingBird
import NIO
import NIOHTTP1

struct TestMiddleware: Middleware {
    func apply(to request: Request, next: RequestResponder) -> EventLoopFuture<Response> {
        return next.respond(to: request).map { response in
            if case .byteBuffer(var buffer) = response.body {
                buffer.writeString("\ntest\n")
                return Response(status: .ok, headers: response.headers, body: .byteBuffer(buffer))
            }
            return response
        }
    }
}

struct DebugMiddleware: Middleware {
    func apply(to request: Request, next: RequestResponder) -> EventLoopFuture<Response> {
        print("\(request.method): \(request.uri)")
        return next.respond(to: request)
    }
}

struct User: Codable {
    let name: String
    let age: Int
}

let app = Application()
app.addHTTP(.init(host: "localhost", port: 8000))
app.encoder = XMLEncoder()
app.decoder = XMLDecoder()

app.logger.logLevel = .debug

app.middlewares.add(DebugMiddleware())
app.middlewares.add(FileMiddleware(app: app))

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

app.router.put("/user/name") { request -> EventLoopFuture<String> in
    guard let user = try? request.decode(as: User.self) else { return request.eventLoop.makeFailedFuture(HTTPError(.badRequest)) }
    return request.eventLoop.makeSucceededFuture("Hello \(user.name)")
}

app.router.put("/user") { request -> EventLoopFuture<User> in
    guard let user = try? request.decode(as: User.self) else { return request.eventLoop.makeFailedFuture(HTTPError(.badRequest)) }
    let newUser = User(name: user.name, age: user.age+1)
    return request.eventLoop.makeSucceededFuture(newUser)
}

let group = app.router.group()
    .add(middleware: TestMiddleware())

group.get("/test") { request -> EventLoopFuture<ByteBuffer> in
    let response = request.allocator.buffer(string: "GoodBye")
    return request.eventLoop.makeSucceededFuture(response)
}

app.serve()
