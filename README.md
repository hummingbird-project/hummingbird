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
<a href="https://discord.gg/4twfgYqdat">
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

Hummingbird's core is designed to be minimal, with additional features provided through extensions. Here are some official extensions:

### Built-in Extensions

- `HummingbirdRouter`: An alternative router using result builders
- `HummingbirdTLS`: TLS support
- `HummingbirdHTTP2`: HTTP2 upgrade support
- `HummingbirdTesting`: Helper functions for testing Hummingbird projects

### Additional Extensions

The following extensions are available in separate repositories:

- [HummingbirdAuth](https://github.com/hummingbird-project/hummingbird-auth): Authentication framework
- [HummingbirdFluent](https://github.com/hummingbird-project/hummingbird-fluent): Integration with Vapor's FluentKit ORM
- [HummingbirdRedis](https://github.com/hummingbird-project/hummingbird-redis): Redis support via RediStack
- [HummingbirdWebSocket](https://github.com/hummingbird-project/hummingbird-websocket): WebSocket support
- [HummingbirdLambda](https://github.com/hummingbird-project/hummingbird-lambda): Run Hummingbird on AWS Lambda
- [Jobs](https://github.com/hummingbird-project/swift-jobs): Job Queue Framework
- [Mustache](https://github.com/hummingbird-project/swift-mustache): Mustache templating engine

## Documentation

You can find reference documentation and user guides for Hummingbird [here](https://docs.hummingbird.codes/2.0/documentation/hummingbird/). The [hummingbird-examples](https://github.com/hummingbird-project/hummingbird-examples/tree/main) repository has a number of examples of different uses of the library.

## Installation

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0")
],
targets: [
  .executableTarget(
    name: "MyApp",
    dependencies: [
        .target(name: "Hummingbird"),
    ]),
]
```

Or run the following commands on your package using SwiftPM, replacing `MyApp` with the name of your target:

```swift
swift package add-dependency https://github.com/hummingbird-project/hummingbird.git --from 2.0.0
swift package add-target-dependency Hummingbird MyApp
```

## Contributing

We welcome contributions to Hummingbird! Please read our [contributing guidelines](CONTRIBUTING.md) before submitting a pull request.

## License

Hummingbird is released under the [Apache 2.0 license](LICENSE.txt).
