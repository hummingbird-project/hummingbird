# ``HummingbirdCore``

Swift NIO based HTTP server. 

## Overview

HummingbirdCore contains a Swift NIO based server. The server is setup with a type conforming `ChannelSetup` which defines how the server responds. It has two functions `initialize` defines how to setup a server channel ie should it be HTTP1, should it include TLS etc and `handle` defines how we should respond to individual messages. For example the following is an HTTP1 server that always returns a response containing the word "Hello" in the body. 

```swift
let server = Server(
    childChannelSetup: HTTP1Channel { (_, responseWriter: consuming ResponseWriter, _) in
        let responseBody = ByteBuffer(string: "Hello")
        var bodyWriter = try await responseWriter.writeHead(.init(status: .ok))
        try await bodyWriter.write(responseBody)
        try await bodyWriter.finish(nil)
    },
    configuration: .init(address: .hostname(port: 8080)),
    eventLoopGroup: eventLoopGroup,
    logger: Logger(label: "HelloServer")
)
```

> Note: In general you won't need to create a `Server` directly. You would let ``Hummingbird/Application`` do this for you. But the ability is left open to you if you want to write your own HTTP server.

## Lifecycle management

Hummingbird makes use of [Swift Service Lifecycle](https://github.com/swift-server/swift-service-lifecycle) to manage startup and shutdown. `Server` conforms to the `Service` protocol required by Swift Service Lifecycle. The following will start the above server and ensure it shuts down gracefully on a shutdown signal.

```swift
let serviceGroup = ServiceGroup(
    services: [server],
    configuration: .init(gracefulShutdownSignals: [.sigterm, .sigint]),
    logger: logger
)
try await serviceGroup.run()
```

## Topics

### Server

- ``Server``
- ``ServerConfiguration``
- ``ServerChildChannel``
- ``ServerChildChannelValue``
- ``BindAddress``
- ``AvailableConnectionsChannelHandler``
- ``AvailableConnectionsDelegate``
- ``MaximumAvailableConnections``
- ``TSTLSOptions``

### HTTP Server

- ``HTTPServerBuilder``
- ``HTTPChannelHandler``
- ``HTTP1Channel``
- ``HTTPConnectionStateHandler``
- ``HTTPUserEventHandler``

### Request

- ``Request``
- ``URI``
- ``RequestBody``

### Response

- ``Response``
- ``ResponseBody``
- ``ResponseWriter``
- ``ResponseBodyWriter``

### Miscellaneous

- ``FlatDictionary``

## See Also

- ``Hummingbird``
- ``HummingbirdHTTP2``
- ``HummingbirdTLS``
