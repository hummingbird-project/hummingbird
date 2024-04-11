<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://opticalaberration.com/images/hummingbird-white-text@0.5x.png">
  <img src="https://opticalaberration.com/images/hummingbird-black-text@0.5x.png">
</picture>
<p align="center">
<a href="https://swift.org">
  <img src="https://img.shields.io/badge/swift-5.9-brightgreen.svg"/>
</a>
<a href="https://github.com/hummingbird-project/hummingbird/actions?query=workflow%3ACI">
  <img src="https://github.com/hummingbird-project/hummingbird/actions/workflows/ci.yml/badge.svg?branch=main"/>
</a>
<a href="https://discord.gg/7ME3nZ7mP2">
  <img src="https://img.shields.io/badge/chat-discord-brightgreen.svg"/>
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

Hummingbird v2 is currently in development an [beta release](https://github.com/hummingbird-project/hummingbird/releases/tag/2.0.0-beta.2) is available if you'd like to try it out.

### Hummingbird Extensions

Hummingbird is designed to require the least number of dependencies possible, but this means many features are unavailable to the core libraries. Additional features are provided through extensions. The Hummingbird repository comes with additional modules 

- `HummingbirdJobs`: framework for pushing work onto a queue to be processed outside of a request (possibly by another server instance).
- `HummingbirdRouter`: an alternative router that uses a resultbuilder.
- `HummingbirdTLS`: TLS support.
- `HummingbirdHTTP2`: Support for HTTP2 upgrades.
- `HummingbirdTesting`: helper functions to aid testing Hummingbird projects.

And also the following are available in other repositories in this organisation

- [`HummingbirdAuth`](https://github.com/hummingbird-project/hummingbird-auth/tree/main): Authentication framework
- [`HummingbirdFluent`](https://github.com/hummingbird-project/hummingbird-fluent/tree/main): Integration with Vapor's database ORM [FluentKit](https://github.com/Vapor/fluent-kit).
- [`HummingbirdLambda`](https://github.com/hummingbird-project/hummingbird-lambda/tree/main): Framework for running Hummingbird on AWS Lambdas.
- [`HummingbirdMustache`](https://github.com/hummingbird-project/hummingbird-mustache): Mustache templating engine.
- [`HummingbirdRedis`](https://github.com/hummingbird-project/hummingbird-redis/tree/main): Redis support via [RediStack](https://github.com/swift-server/RediStack).
- [`HummingbirdWebSocket`](https://github.com/hummingbird-project/hummingbird-websocker/tree/main): Support for WebSockets (Currently work in progess).

## Documentation

You can find reference documentation and user guides for Hummingbird [here](https://docs.hummingbird.codes/2.0/documentation/hummingbird/). The [hummingbird-examples](https://github.com/hummingbird-project/hummingbird-examples/tree/main) repository has a number of examples of different uses of the library.
