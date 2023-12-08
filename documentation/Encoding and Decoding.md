#  Encoding and Decoding

Hummingbird can make use of `Codable` to decode requests and encode responses. `HBApplication` has two member variables `decoder` and `encoder` which define how requests/responses are decoded/encoded. The `decoder` must conform to `HBRequestDecoder` which requires a `decode(_:from)` function that decodes a `HBRequest`. 

```swift
public protocol HBRequestDecoder {
    func decode<T: Decodable>(_ type: T.Type, from request: HBRequest) throws -> T
}
```

The `encoder` must conform to `HBResponseEncoder` which requires a `encode(_:from)` function that creates a `HBResponse` from a `Codable` value and the original request that generated it.

```swift
public protocol HBResponseEncoder {
    func encode<T: Encodable>(_ value: T, from request: HBRequest) throws -> HBResponse
}
```

Both of these look very similar to the `Encodable` and `Decodable` protocol that come with the `Codable` system except you have additional information from the `HBRequest` class on how you might want to decode/encode your data.

## Setting up HBApplication

The default implementations of `decoder` and `encoder` are `Null` implementations that will assert if used. So you have to setup your `decoder` and `encoder` before you can use `Codable` in Hummingbird. `HummingbirdFoundation` includes two such implementations. `JSONEncoder` and `JSONDecoder` have been extended to conform to the relevant protocols so you can have JSON decoding/encoding by adding the following when creating your application

```swift
let app = HBApplication()
app.decoder = JSONDecoder()
app.encoder = JSONEncoder()
```

`HummingbirdFoundation` also includes a decoder and encoder for url encoded form data. To use this you setup the application as follows

```swift
let app = HBApplication()
app.decoder = URLEncodedFormDecoder()
app.encoder = URLEncodedFormEncoder()
```

## Decoding Requests

Once you have a decoder you can implement decoding in your routes using the `HBRequest.decode` method in the following manner

```swift
struct User: Decodable {
    let email: String
    let firstName: String
    let surname: String
}
app.router.post("user") { request async throws -> HTTPResponseStatus in
    // decode user from request
    guard let user = try? request.decode(as: User.self) else {
        throw HBHTTPError(.badRequest)
    }
    // create user and if ok return `.ok` status
    return try await createUser(user)
}
```
Like the standard `Decoder.decode` functions `HBRequest.decode` can throw an error if decoding fails. In this situation when I received a decode error I throw a bad request error. I HBHTTPError to ensure that the error gets converted to an HTTP response with that status code.

## Encoding Responses

To have an object encoded in the response we have to conform it to `HBResponseEncodable`. This then allows you to create a route handler that returns this object and it will automatically get encoded. If we extend the `User` object from the above example we can do this

```swift
extension User: HBResponseEncodable {}

app.router.get("user") { request -> User in
    let user = User(email: "js@email.com", name: "John Smith")
    return user
}
```

## Decoding/Encoding based on Request headers

Because the full request is supplied to the `HBRequestDecoder`. You can make decoding decisions based on headers in the request. In the example below we are decoding using either the `JSONDecoder` or `URLEncodedFormDecoder` based on the "content-type" header.

```swift
struct MyRequestDecoder: HBRequestDecoder {
    func decode<T>(_ type: T.Type, from request: HBRequest) throws -> T where T : Decodable {
        guard let header = request.headers["content-type"].first else { throw HBHTTPError(.badRequest) }
        guard let mediaType = HBMediaType(from: header) else { throw HBHTTPError(.badRequest) }
        switch mediaType {
        case .applicationJson:
            return try JSONDecoder().decode(type, from: request)
        case .applicationUrlEncoded:
            return try URLEncodedFormDecoder().decode(type, from: request)
        default:
            throw HBHTTPError(.badRequest)
        }
    }
}
```

Using a similar manner you could also create a `HBResponseEncoder` based on the "accepts" header in the request.
