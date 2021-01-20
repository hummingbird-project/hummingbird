# Hummingbird

Lightweight server framework based off Swift NIO. Hummingbird is designed to require the minimum number of dependencies. The core library `Hummingbird` requires `swift-backtrace`, `swift-log`, `swift-nio`, `swift-nio-extras`, `swift-service-lifecycle` and `swift-trace` and makes no use of Foundation.

Hummingbird is easy to extended. You can add middleware for processing requests before they reach your handlers and process the responses returned, add additional channel handlers to the server, extend the `Application`, `Request`, `Response` classes and provide custom encoding/decoding of `Codable` objects. 

The Hummingbird repository contains additional libraries to extend the framework to support some commonly required features. These have less limitations on what dependencies they can bring in. They currently include

- HummingbirdFiles: static file serving (uses Foundation)
- HummingbirdJSON: JSON encoding and decoding (uses Foundation)
- HummingbirdTLS: TLS support (use NIOSSL)

The list is not very long at the moment but we intend to extend this. 

## Usage

This is a basic setup for a server. It binds to port 8000 on localhost, adds a route for path "/" that returns "Hello" in the response body.
```swift
import Hummingbird

let app = Application(configuration: .init(address: .hostname("127.0.0.1", port: 8080)))
app.router.get("/") { request -> String in
    return "Hello"
}
app.start()
app.wait()
```

