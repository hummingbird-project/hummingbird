# hummingbird

Lightweight server framework based off Swift NIO

## Usage

```swift
import HummingBird

let app = Application()
app.addHTTP(.init(host: "localhost", port: 8000))
app.router.get("/") { request -> String in
    return "Hello"
}
app.router.get("user") { request -> EventLoopFuture<User> in
    return callDatabaseToGetUser()
}
app.start()
app.wait()
```
