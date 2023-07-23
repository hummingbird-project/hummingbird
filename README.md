![# Hummingbird](https://opticalaberration.com/images/hummingbird-white-text@0.5x.png#gh-dark-mode-only)
![# Hummingbird](https://opticalaberration.com/images/hummingbird-black-text@0.5x.png#gh-light-mode-only)

Lightweight, flexible server framework written in Swift.

Hummingbird consists of three main components, the core HTTP server, a minimal web application framework and the extension modules.

## HummingbirdCore

HummingbirdCore contains a Swift NIO based HTTP server. You will find the code for it in the [hummingbird-core](https://github.com/hummingbird-project/hummingbird-core) repository. The HTTP server is initialized with a object conforming to protocol `HBHTTPResponder` which defines how your server responds to an HTTP request. The HTTP server can be extended to support TLS and HTTP2 via the `HummingbirdTLS` and `HummingbirdHTTP2` libraries also available in the hummingbird-core repository.

HummingbirdCore can be used separately from Hummingbird if you want to write your own web application framework.

## Hummingbird

Hummingbird is a lightweight and flexible web application framework that runs on top of HummingbirdCore. It is designed to require the minimum number of dependencies: `swift-backtrace`, `swift-log`, `swift-nio`, `swift-nio-extras`, `swift-service-lifecycle` and `swift-metrics` and makes no use of Foundation.

It provides a router for directing different endpoints to their handlers, middleware for processing requests before they reach your handlers and processing the responses returned, support for adding channel handlers to extend the HTTP server, extending the core `HBApplication`, `HBRequest` and `HBResponse` classes and providing custom encoding/decoding of `Codable` objects.

The interface is fairly standard. Anyone who has had experience of Vapor, Express.js etc will recognise most of the APIs. Simple setup is as follows

```swift
import Hummingbird

let app = HBApplication(configuration: .init(address: .hostname("127.0.0.1", port: 8080)))
app.router.get("hello") { request -> String in
    return "Hello"
}
try app.start()
app.wait()
```

## Hummingbird Extensions

Hummingbird is designed to require the least number of dependencies possible, but this means many features are unavailable to the core libraries. Additional features are provided through extensions. The Hummingbird repository comes with a `HummingbirdFoundation` library that contains a number of features that can only really be implemented with the help of Foundation. This include JSON encoding/decoding, URLEncodedForms, static file serving, and cookies.

Extensions provided in other repositories include

| Extension | Description |
|-----------|-------------|
| [HummingbirdAuth](https://github.com/hummingbird-project/hummingbird-auth) | Authentication framework and various support libraries
| [HummingbirdCompress](https://github.com/hummingbird-project/hummingbird-compression) | Request decompression and response compression (uses [CompressNIO](https://github.com/adam-fowler/compress-nio))
| [HummingbirdFluent](https://github.com/hummingbird-project/hummingbird-fluent) | Interface to the Vapor database ORM (uses [FluentKit](https://github.com/vapor/fluent))
| [HummingbirdRedis](https://github.com/hummingbird-project/hummingbird-redis) | Interface to Redis (uses [RediStack](https://gitlab.com/mordil/RediStack))
| [HummingbirdWebSocket](https://github.com/hummingbird-project/hummingbird-websocket) | Adds support for WebSocket upgrade to server
| [HummingbirdMustache](https://github.com/hummingbird-project/hummingbird-mustache) | Mustache templating engine
| [HummingbirdLambda](https://github.com/hummingbird-project/hummingbird-lambda) | Run hummmingbird inside an AWS Lambda

## Documentation

You can find reference documentation and user guides for Hummingbird [here](https://hummingbird-project.github.io/hummingbird-docs/documentation/hummingbird/). The [hummingbird-examples](https://github.com/hummingbird-project/hummingbird-examples) repository has a number of examples of different uses of the library.
