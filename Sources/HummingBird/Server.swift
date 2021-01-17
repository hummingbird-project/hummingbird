import NIO

public protocol Server {
    func start(application: Application) -> EventLoopFuture<Void>
    func stop() -> EventLoopFuture<Void>
}
