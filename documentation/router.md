### Router

The router uses a Trie based search to choose the correct handler. You can supply it with handlers that return a type or an `EventLoopFuture` that will be fulfilled with that type at a later point. The core library comes with support for returning `ByteBuffers`, `Strings` and `HTTPResponseStatus`. 

`Codable` types can be encoded and decoded by conforming to `ResponseEncodable` or `ResponseCodable`. How they are encoded/decoded is defined by `encoder` and `decoder` variables in `Application`. These require conformance to the type `ResponseEncoder`/`RequestDecoder`. The library HummingbirdJSON extends the standard Foundation `JSONEncoder` to conform to `ResponseEncoder` and `JSONDecoder` to `RequestDecoder`.

```swift
import Hummingbird
import HummingbirdJSON

struct User: ResponseEncodable {
    let name: String
    let email: String
}
let app = Application(configuration: .init(address: .hostname("0.0.0.0", port: 8080)))
app.encoder = JSONEncoder()
app.router.get("user") { request -> User in
    return User(name: "John", email: "john@email.com")
}
```

Routes can also include wildcards and have parameters extracted from them. A "*" indicates a path component that can be anything. If you prefix a path component with a ":" then it will extract the contents of that path component to be available in the handler. Below is an example of extracting a parameter

```swift
app.router.get("user/:id") { request -> String in 
    guard let id = request.parameters.get("id", as: Int.self) else { 
        throw HTTPError(.badRequest) 
    }
    return "User id = \(id)"
}
```
