<p align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://github.com/hummingbird-project/hummingbird/assets/9382567/48de534f-8301-44bd-b117-dfb614909efd">
  <img src="https://github.com/hummingbird-project/hummingbird/assets/9382567/e371ead8-7ca1-43e3-8077-61d8b5eab879">
</picture>
</p>  
<p align="center">
<a href="https://swift.org">
  <img src="https://img.shields.io/badge/swift-6.0-f05138.svg"/>
</a>
<a href="https://swift.org">
  <img src="https://img.shields.io/badge/swift-5.9+-f05138.svg"/>
</a>
<a href="https://github.com/hummingbird-project/hummingbird/actions?query=workflow%3ACI">
  <img src="https://github.com/hummingbird-project/hummingbird/actions/workflows/ci.yml/badge.svg?branch=main"/>
</a>
<a href="https://discord.gg/7ME3nZ7mP2">
  <img src="https://img.shields.io/badge/chat-discord-7289da.svg?logo=discord&logoColor=white"/>
</a>
</p>

Lightweight, flexible, modern server framework written in Swift.

## Hummingbird

Hummingbird is a lightweight, flexible modern web application framework that runs on top of a SwiftNIO based server implementation. It is designed to require the minimum number of dependencies.

It provides a router for directing different endpoints to their handlers, middleware for processing requests before they reach your handlers and processing the responses returned, custom encoding/decoding of requests/responses, TLS and HTTP2.

```swift
import Hummingbird

// create router and add a single GET /hello route
let router = Router()
router.get("hello") { request, _ -> String in
    return "Hello"
}
// create application using router
let app = Application(
    router: router,
    configuration: .init(address: .hostname("127.0.0.1", port: 8080))
)
// run hummingbird application
try await app.runService()
```

### Extending Hummingbird

Hummingbird is designed to require the least number of dependencies possible, but this means many features are unavailable to the core libraries. Additional features are provided through extensions. The Hummingbird repository comes with additional modules 

- `HummingbirdRouter`: an alternative router that uses a resultbuilder.
- `HummingbirdTLS`: TLS support.
- `HummingbirdHTTP2`: Support for HTTP2 upgrades.
- `HummingbirdTesting`: helper functions to aid testing Hummingbird projects.

And also the following are available in other repositories in this organisation

- [`HummingbirdAuth`](https://github.com/hummingbird-project/hummingbird-auth/tree/main): Authentication framework
- [`HummingbirdFluent`](https://github.com/hummingbird-project/hummingbird-fluent/tree/main): Integration with Vapor's database ORM [FluentKit](https://github.com/Vapor/fluent-kit).
- [`HummingbirdRedis`](https://github.com/hummingbird-project/hummingbird-redis/tree/main): Redis support via [RediStack](https://github.com/swift-server/RediStack).
- [`HummingbirdWebSocket`](https://github.com/hummingbird-project/hummingbird-websocket/tree/main): Support for WebSockets (Currently work in progess).
- [`HummingbirdLambda`](https://github.com/hummingbird-project/hummingbird-lambda/tree/main): Framework for running Hummingbird on AWS Lambdas.
- [`Jobs`](https://github.com/hummingbird-project/swift-jobs/tree/main): Job Queue Framework
- [`Mustache`](https://github.com/hummingbird-project/swift-mustache): Mustache templating engine.

## Documentation

You can find reference documentation and user guides for Hummingbird [here](https://docs.hummingbird.codes/2.0/documentation/hummingbird/). The [hummingbird-examples](https://github.com/hummingbird-project/hummingbird-examples/tree/main) repository has a number of examples of different uses of the library.
