#  Error Handling

If a middleware or route handler throws an error the server needs to know how to handle this. If the server does not know how to handle the error then the only thing it can return to the client is a status code of 500 (Internal Server Error). This is not overly informative.

## HBHTTPError

Hummingbird uses the Error object `HBHTTPError` throughout its codebase. The server recognises this and can generate a more informative response for the client from it. The error includes the status code that should be returned and a response message if needed. For example 

```swift
app.get("user") { request -> User in
    guard let userId = request.uri.queryParameters.get("id", as: Int.self) else {
        throw HBHTTPError(.badRequest, message: "Invalid user id")
    }
    ...
}
```
The `HBHTTPError` generated here will be recognised by the server and it will generate a status code 400 (Bad Request) with the body "Invalid user id".

In the situation where you have a route that returns an `EventLoopFuture` you are not allowed to throw an error so you have to return a failed `EventLoopFuture`. Hummingbird provides a shortcut here for you `context.failure`. It can be used as follows

```swift
app.get("user") { request -> EventLoopFuture<User> in
    guard let userId = request.uri.queryParameters.get("id", as: Int.self) else {
        throw HBHTTPError(.badRequest, message: "Invalid user id")
    }
    ...
}
```

## HBHTTPResponseError

The server knows how to respond to a `HBHTTPError` because it conforms to protocol `HBHTTPResponseError`. You can create your own `Error` object and conform it to `HBHTTPResponseError` and the server will know how to generate a sensible error from it. The example below is a error class that outputs an error code in the response headers.

```swift
struct MyError: HBHTTPResponseError {
    init(_ status: HTTPResponseStatus, errorCode: String) {
        self.status = status
        self.errorCode = errorCode
    }

    let errorCode: String

    // required by HBHTTPResponseError protocol
    let status: HTTPResponseStatus
    var headers: HTTPHeaders { ["error-code": self.errorCode] }
    func body(allocator: ByteBufferAllocator) -> ByteBuffer? {
        return nil
    }
}
```
