# HummingbirdCore

Swift NIO based HTTP server. The core HTTP server component for the [Hummingbird](https://github.com/hummingbird-project/hummingbird) web framework. 

## Usage

HummingbirdCore contains a Swift NIO based HTTP server. When starting the server you provide it with a struct that conforms to `HBHTTPResponder` to define how the server should respond to requests. For example the following is a responder that always returns a response containing the word "Hello" in the body. 

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

The following will start up a server using the above `HelloResponder`.

```swift
let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
let server = HBHTTPServer(
    group: eventLoopGroup, 
    configuration: .init(address: .hostname("127.0.0.1", port: 8080))
)
try server.start(responder: HelloResponder()).wait()
// Wait until server closes which never happens as server channel is never closed
try server.wait()
```

## Swift service lifecycle

If you are using HummingbirdCore outside of Hummingbird ideally you would use it along with the swift-server library [swift-service-lifecycle](https://github.com/swift-server/swift-service-lifecycle). This gives you a framework for clean initialization and shutdown of your server. The following sets up a Lifecycle that initializes the HTTP server and stops it when the application shuts down.
```swift
import Lifecycle
import LifecycleNIOCompat

let lifecycle = ServiceLifecycle()
lifecycle.register(
    label: "HTTP Server",
    start: .eventLoopFuture { self.server.start(responder: MyResponder()) },
    shutdown: .eventLoopFuture(self.server.stop)
)
lifecycle.start { error in
    if let error = error {
        print("ERROR: \(error)")
    }
}
lifecycle.wait()
```

## HummingbirdCore Extensions

The HummingbirdCore can be extended to support TLS and HTTP2 via the HummingbirdTLS and HummingbirdHTTP2 libraries. The following will add TLS support
```swift
import HummingbirdTLS
server.addTLS(tlsConfiguration: myTLSConfiguration)
```
and this will add an HTTP2 upgrade option
```swift
import HummingbirdHTTP2
server.addHTTP2Upgrade(tlsConfiguration: myTLSConfiguration)
```
As the HTTP2 upgrade requires a TLS connection this is added automatically when enabling HTTP2 upgrade. So don't call both function as this will setup two TLS handlers.
