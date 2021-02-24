#  Extending Hummingbird

The `HBApplication`, `HBRequest` and `HBResponse` classes all contain an `HBExtensions` object that allows you to extend these classes with your own objects. The extension objects are stored in a dictionary with a KeyPath as their key. 

```swift
extension HBApplication {
    public var myExt: String? {
        get { self.extensions.get(\.myExt) }
        set { self.extensions.set(\.myExt, value: newValue) }
    }
}
```
The code above adds the member variable `myExt` to the `HBApplication` class. I use the `KeyPath` to the variable as the key. While it would be possible to use another `KeyPath` as the key it doesn't really make sense. 

In the example above the member variable is an optional, to ensure you will always get a valid value when referencing `HBApplication.myExt`. You can set the variable to be non-optional but you will have to ensure you set the variable before ever accessing it, otherwise your application will crash.

For extensions to `HBApplication` you also get the added bonus of being able to add a shutdown call for when the application is shutdown. In the example below we have extended `HBApplication` to include a `AWSClient` from the package [`Soto`](https://github.com/soto-project/soto). It is required you shutdown the client before it is deleted. The extension shutdown can be used to do this for you.

```swift
extension HBApplication {
    public struct AWS {
        public var client: AWSClient {
            get { application.extensions.get(\.aws.client) }
            nonmutating set {
                application.extensions.set(\.aws.client, value: newValue) { client in
                    // shutdown AWSClient
                    try client.syncShutdown()
                }
            }
        }
        let application: HBApplication
    }

    public var aws: AWS { return .init(application: self) }
}
```

Note, I have placed everything inside a containing struct `AWS`, so the KeyPath `\.aws.client` needs to include the name of containing member variable in it as well. 

## Extending EventLoop

In certain situations it can be useful to hold data on a per `EventLoop` basis. You can do this by extending the class `HBApplication.EventLoopStorage`. The class can be extended in the same way as above. You then access the storage either via `HBApplication.eventLoopStorage(for:)` or `HBRequest.eventLoopStorage`. 
```swift
extension HBApplication.EventLoopStorage {
    public var index: Int? {
        get { self.extensions.get(\.index) }
        set { self.extensions.set(\.index, value: newValue) }
    }
}
func getIndex(_ request: HBRequest) {
    let index = request.eventLoopStorage.index
    ...
}
```

This is used by the `DateCache` in `HummingbirdFoundation` and also by the `Redis` interface that can be found [here](https://github.com/hummingbird-project/hummingbird-redis).
