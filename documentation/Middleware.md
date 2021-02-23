#  Middleware

Middleware can be used to edit requests before they are forwared to the router, edit the responses returned by the route handlers or even shortcut the router and return their own responses. Middleware is added to the application as follows.

```swift
let app = HBApplication()
app.middleware.add(MyMiddlware())
```

## Groups

Middleware can also be applied to a specific set of routes using groups. Below is a example of applying authentication middleware to routes that need protected.

```swift
let app = HBApplication()
app.router.put("/user", createUser)
app.router.group()
    .add(middleware: BasicAuthenticatorMiddleware())
    .post("/user", loginUser)
```
The first route that calls `createUser` does not have the `BasicAuthenticatorMiddleware` applied to it. But the route calling `loginUser` which is inside the group does have the middleware applied.

## Writing Middleware

All middleware has to conform to the protocol `HBMiddleware`. This requires one function `apply(to:next)` to be implemented. At some point in this function unless you want to shortcut the router and return your own reponse you are required to call `next.respond(to: request)` and return the result, or a result processed by the middleware. The following is a simple logging middleware that outputs every URI being sent to the server

```swift
public struct LogRequestsMiddleware: HBMiddleware {
    public func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
        request.logger.log(level: .debug, String(describing:request.path))
        return next.respond(to: request)
    }
}
```

If you want to process the response after it has been returned by the route handler you will need to use run a function on the `EventLoopFuture` returned by `next.respond`. 
```swift
public struct ResponseProcessingMiddleware: HBMiddleware {
    public func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
        return next.respond(to: request).map { response in
            return processResponse(response)
        }
        .flatMapError { error in
            return processError(error)
        }
    }
}
```