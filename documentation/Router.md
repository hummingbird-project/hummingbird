#  Router

The router: `HBApplication.router` directs requests to their handlers based on the contents of their path. The router that comes with Hummingbird uses a Trie based lookup. Routes are added using the function `on`. You provide the URI path, the method and the handler function. Below is a simple route which returns "Hello" in the body of the response.

```swift
let app = HBApplication()
app.router.on("/hello", method: .GET) { request in
    return "Hello"
}
```
If you don't provide a path then the default is for it to be "/".

## Methods

There are shortcut functions for common HTTP methods. The above can be written as

```swift
let app = HBApplication()
app.router.get("/hello") { request in
    return "Hello"
}
```

There are shortcuts for `put`, `post`, `head`, `patch` and `delete` as well.

## Response generators

Route handlers are required to return either a type conforming to the `HBResponseGenerator` protocol or an `EventLoopFuture` of a type conforming to `HBResponseGenerator`. An `EventLoopFuture` is an object that will fulfilled with their value at a later date in an asynchronous manner. The `HBResponseGenerator` protocol requires an object to be able to generate an `HBResponse`. For example `String` has been extended to conform to `HBResponseGenerator` by returning an `HBResponse` with status `.ok`,  a content-type header of `text-plain` and a body holding the contents of the `String`. 
```swift
/// Extend String to conform to ResponseGenerator
extension String: HBResponseGenerator {
    /// Generate response holding string
    public func response(from request: HBRequest) -> HBResponse {
        let buffer = context.allocator.buffer(string: self)
        return HBResponse(status: .ok, headers: ["content-type": "text/plain; charset=utf-8"], body: .byteBuffer(buffer))
    }
}
```

In addition to `String` `ByteBuffer`, `HTTPResponseStatus` and `Optional` have also been extended to conform to `HBResponseGenerator`.

It is also possible to extend `Codable` objects to generate `HBResponses` by conforming these objects to `HBResponseEncodable`. The object will use `HBApplication.encoder` to encode these objects. If an object conforms to `HBResponseEncodable` then also so do arrays of these objects and dictionaries.

## Parameters

You can extract parameters out of the URI by prefixing the path with a colon. This indicates that this path section is a parameter. The parameter name is the string following the colon. You can get access to the parameters extracted from the URI with `HBRequest.parameters`. If there are no URI parameters in the path, accessing `HBRequest.parameters` will cause a crash, so don't use it if you haven't specified a parameter in the route path. This example extracts an id from the URI and uses it to return a specific user. so "/user/56" will return user with id 56. 

```swift
let app = HBApplication()
app.router.get("/user/:id") { request in
    let id = request.parameters.get("id", as: Int.self) else { throw HBHTTPError(.badRequest) }
    return getUser(id: id)
}
```
In the example above if I fail to access the parameter as an `Int` then I throw an error. If you throw an `HBHTTPError` it will get converted to a valid HTTP response.

## Groups

Routes can be grouped together in a `HBRouterGroup`.  These allow for you to prefix a series of routes with the same path and more importantly apply middleware to only those routes. The example below is a group that includes five handlers all prefixed with the path "/todos".

```swift
let app = HBApplication()
app.router.group("/todos")
    .put(use: createTodo)
    .get(use: listTodos)
    .get(":id", getTodo)
    .patch(":id", editTodo)
    .delete(":id", deleteTodo)
```

## Route handlers

A route handler `HBRouteHandler` allows you to encapsulate all the components required for a route, and provide separation of the extraction of input parameters from the request and the processing of those parameters. An example could be structrured as follows

```swift
struct AddOrder: HBRouteHandler {
    struct Input: Decodable {
        let name: String
        let amount: Double
    }
    struct Output: HBResponseEncodable {
        let id: String
    }
    let input: Input
    let user: User
    
    init(from request: HBRequest) throws {
        self.input = try request.decode(as: Input.self)
        self.user = try request.auth.require(User.self)
    }
    func handle(request: HBRequest) -> EventLoopFuture<Output> {
        let order = Order(user: self.user.id, details: self.input)
        return order.save(on: request.db)
            .map { .init(id: order.id) }
    }
}
```
Here you can see the `AddOrder` route handler encapsulates everything you need to know about the add order route. The `Input` and `Output` structs are defined and any additional input parameters that need extracted from the `HBRequest`. The input parameters are extracted in the `init` and then the request is processed in the `handle` function. In this example we need to decode the `Input` from the `HBRequest` and using the authentication framework from `HummingbirdAuth` we get the authenticated user. 

The following will add the handler to the application
```swift
application.router.put("order", use: AddOrder.self)
```

## Streaming request body

By default Hummingbird will collate the contents of your request body into one ByteBuffer. You can access this via `HBRequest.body.buffer`. If you'd prefer to stream the content of the request body, you can add a `.streamBody` option to the route handler to receive a streaming body instead of a single `ByteBuffer`. Inside the route handler you access this stream via `HBRequest.body.stream`. The request body parts are then accessed either via `consume` function which will return everything that has been streamed so far or a `consumeAll` function which takes a closure processing each part. Here is an example which reads the request buffer and returns it size
```swift
application.router.post("size", options: .streamBody) { request -> EventLoopFuture<String> in
    guard let stream = request.body.stream else { 
        return context.failure(.badRequest)
    }
    var size = 0
    return stream.consumeAll(on: context.eventLoop) { buffer in
        size += buffer.readableBytes
        return context.eventLoop.makeSucceededFuture(())
    }
    .map { size.description }
}
```

## Editing response in handler

The standard way to provide a custom response from a route handler is to return a `HBResponse` from that handler. This method loses a lot of the automation of encoding responses, generating the correct status code etc. 

There is another method though that allows you to edit a response even when returning something other than a `HBResponse`. First you need to flag your route to say it is editing the response using the option `.editResponse`. Once you have set this option you can edit your response via `HBRequest.response`. This allows you to add new headers, replace generated headers or set the status code. Below is a route replacing the generated `content-type` header and setting the status code.
```swift
application.router.post("test", options: .editResponse) { request -> String in
    request.response.headers.replaceOrAdd(name: "content-type", value: "application/json")
    request.response.status = .accepted
    return #"{"test": "value"}"#
}
```
