# Hummingbird

Lightweight, flexible server framework written in Swift.

Hummingbird consists of three main components, the core HTTP server, a minimal web application framework and the extension modules.

## HummingbirdCore

HummingbirdCore provides a Swift NIO based HTTP server. You provide it with an struct that conforms to `HBHTTPResponder` to define how the server should respond to requests. The following is a responder that always returns a response containing the word "Hello" in the body. 

```swift
struct HelloResponder: HBHTTPResponder {
    func respond(to request: HBHTTPRequest, context: ChannelHandlerContext) -> EventLoopFuture<HBHTTPResponse> {
        let response = HBHTTPResponse(
            head: .init(version: .init(major: 1, minor: 1), status: .ok),
            body: .byteBuffer(context.channel.allocator.buffer(string: "Hello"))
        )
        return context.eventLoop.makeSucceededFuture(response)
   }
}    
```

The following will start up a server using the above `HBHTTPResponder`.

```swift
let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
let server = HBHTTPServer(
    group: eventLoopGroup, 
    configuration: .init(address: .hostname(port: 8080))
)
try server.start(responder: HelloResponder()).wait()
// This never happens as server channel is never closed
try? server.channel?.closeFuture.wait()
```

## Hummingbird

Hummingbird is a lightweight and flexible web application framework that runs on top of HummingbirdCore. It is designed to require the minimum number of dependencies: `swift-backtrace`, `swift-log`, `swift-nio`, `swift-nio-extras`, `swift-service-lifecycle` and `swift-metrics` and makes no use of Foundation.

It provides a router for directing different paths to different handlers, middleware for processing requests before they reach your handlers and processing the responses returned, support for adding channel handlers to extend the HTTP server, extending the core `HBApplication`, `HBRequest` and `HBResponse` classes and providing custom encoding/decoding of `Codable` objects.

The interface is fairly standard. Anyone who has had experience of Vapor, Express.js will recognise the interfaces. Simple setup is as follows

```swift
import Hummingbird

let app = Application(configuration: .init(address: .hostname("127.0.0.1", port: 8080)))
app.router.get("hello") { request -> String in
    return "Hello"
}
app.start()
app.wait()
```

## Hummingbird Extensions

Hummingbird is designed to require the least number of dependencies possible, but this means many features are unavailable to the core libraries. Additional features are provided through extensions. The Hummingbird repository comes with the following extensions

| Extension | Description |
|-----------|-------------|
| HummingbirdFiles | static file serving (uses Foundation) |
| HummingbirdJSON | JSON encoding and decoding (uses Foundation) |
| HummingbirdTLS | TLS support (use NIOSSL) |
| HummingbirdHTTP2 | HTTP2 upgrade support (uses NIOSSL, NIOHTTP2) |

Extensions provided in other repositories include

| Extension | Description |
|-----------|-------------|
| [HummingbirdCompress](https://github.com/hummingbird-project/hummingbird-compression) | Request decompression and response compression (uses [NIOCompress](https://github.com/adam-fowler/compress-nio))
| [HummingbirdFluent](https://github.com/hummingbird-project/hummingbird-fluent) | Interface to the Vapor database ORM (uses [FluentKit](https://github.com/vapor/fluent))

