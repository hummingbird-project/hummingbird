<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://opticalaberration.com/images/hummingbird-white-text@0.5x.png">
  <img src="https://opticalaberration.com/images/hummingbird-black-text@0.5x.png">
</picture>
<p align="center">
<a href="https://swift.org">
  <img src="https://img.shields.io/badge/swift-5.7-brightgreen.svg"/>
</a>
<a href="https://github.com/hummingbird-project/hummingbird/actions?query=workflow%3ACI">
  <img src="https://github.com/hummingbird-project/hummingbird/actions/workflows/ci.yml/badge.svg?branch=main"/>
</a>
<a href="https://discord.gg/7ME3nZ7mP2">
  <img src="https://img.shields.io/badge/chat-discord-brightgreen.svg"/>
</a>
</p>

Lightweight, flexible, modern server framework written in Swift.

## HummingbirdCore

HummingbirdCore contains a Swift NIO based server framework. The server framework `HBServer` can be used to support many protocols but is primarily designed to support HTTP. By default it is setup to be an HTTP/1.1 server, but it can support TLS and HTTP2 via the `HummingbirdTLS` and `HummingbirdHTTP2` modules.

HummingbirdCore can be used separately from Hummingbird if you want to write your own web application framework.

## Hummingbird

Hummingbird is a lightweight and flexible web application framework that runs on top of HummingbirdCore. It is designed to require the minimum number of dependencies and makes no use of Foundation.

It provides a router for directing different endpoints to their handlers, middleware for processing requests before they reach your handlers and processing the responses returned, support for adding channel handlers to extend the HTTP server and providing custom encoding/decoding of `Codable` objects.

```swift
import Hummingbird

let router = HBRouterBuilder()
router.get("hello") { request -> String in
    return "Hello"
}
let app = HBApplication(
    responder: router.buildResponder(),
    configuration: .init(address: .hostname("127.0.0.1", port: 8080))
)
try await app.runService()
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
