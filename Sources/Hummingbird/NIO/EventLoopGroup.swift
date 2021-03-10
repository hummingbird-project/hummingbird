
extension EventLoopGroup {
    /// Run closure on every EventLoop in an EventLoopGroup and return results in an array of `EventLoopFuture`s.
    func map<T>(_ transform: @escaping (EventLoop) -> T) -> [EventLoopFuture<T>] {
        var array: [EventLoopFuture<T>] = []
        for eventLoop in self.makeIterator() {
            let result = eventLoop.submit {
                transform(eventLoop)
            }
            array.append(result)
        }
        return array
    }

    /// Run closure returning `EventLoopFuture` on every EventLoop in an EventLoopGroup and return results in an array of `EventLoopFuture`s.
    func flatMap<T>(_ transform: @escaping (EventLoop) -> EventLoopFuture<T>) -> [EventLoopFuture<T>] {
        var array: [EventLoopFuture<T>] = []
        for eventLoop in self.makeIterator() {
            let result = eventLoop.flatSubmit {
                transform(eventLoop)
            }
            array.append(result)
        }
        return array
    }
}
