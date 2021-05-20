#  Persistent data

If you are looking to store data between requests to your server then the Hummingbird `persist` framework provides a key/value store. Each key is a string and the value can be any object that conforms to `Codable`. 

To create a new entry you can call `create`
```swift
let future = request.persist.create(key: "mykey", value: MyValue)
```
This returns an `EventLoopFuture` which will succeed once the value has been saved. If there is an entry for the key already then the `EventLoopFuture` will fail with the error `HBPersistError.duplicate`.

If you are not concerned about overwriting a previous key/value pair you can use 
```swift
let future = request.persist.set(key: "mykey", value: MyValue)
```

Both `create` and `set` have an `expires` parameter. With this parameter you can make a key/value pair expire after a certain time period. eg
```swift
let future = request.persist.set(key: "sessionID", value: MyValue, expires: .hours(1))
```

To access values in the `persist` key/value store you use 
```swift
let future = request.persist.get(key: "mykey", as: MyValueType.self)
```
This returns an `EventLoopFuture` which will succeed with the value associated with key or `nil` if that value doesn't exist or is not of the type requested.

And finally if you want to delete a key you can use
```swift
let future request.persist.remove(key: "mykey")
```

## Drivers

The `persist` framework defines an API for storing key/value pairs. You also need a driver for the framework. When configuring your application if you want to use `persist` you have to add it to the application and indicate what driver you are going to use. `Hummingbird` comes with a memory based driver which will store these values in the memory of your server. 
```swift
app.addPersist(using: .memory)
```
If you use the memory based driver the key/value pairs you store will be lost if your server goes down. 

## Redis

You can use Redis to store the `persists` key/value pairs with the `HummingbirdRedis` library. You would setup `persist` to use Redis as follows. To use the Redis driver you need to have setup Redis with Hummingbird as well.
```swift
app.addRedis(configuration: .init(hostname: redisHostname, port: 6379))
app.addPersist(using: .redis)
```

## Fluent

`HummingbirdFluent` also contains a `persist` driver for the storing the key/value pairs in a database. To setup the Fluent driver you need to have setup Fluent first. The first time you run with the fluent driver you should ensure you call `fluent.migrate()` after the `addPersist` call has been made.
```swift
app.addFluent()
app.fluent.databases.use(...)
app.addPersist(using: .fluent(databaseID))
if Self.migrate {
    app.fluent.migrate()
}
```

