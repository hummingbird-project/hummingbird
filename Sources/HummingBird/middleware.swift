import NIO

protocol Middleware {
    associatedtype In
    associatedtype Out

    func process(_ in: Int) -> Out
    func add<M: Middleware>(_: M) where M.In == Out
}

extension Middleware {

}
