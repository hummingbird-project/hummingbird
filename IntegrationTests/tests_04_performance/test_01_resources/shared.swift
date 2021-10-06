import Hummingbird
import HummingbirdCoreXCT
import NIO

class Setup {
    let elg: EventLoopGroup
    let app: HBApplication
    let client: HBXCTClient

    init(_ configure: (HBApplication) -> ()) throws {
        self.elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
        self.app = HBApplication(
            configuration: .init(logLevel: .error), 
            eventLoopGroupProvider: .shared(elg)
        )
        self.app.logger.logLevel = .error
        configure(app)

        try app.start()

        self.client = HBXCTClient(host: "localhost", port: app.server.port!, eventLoopGroupProvider: .createNew)
        client.connect()
    }

    deinit {
        try? self.client.syncShutdown()
        self.app.stop()
        self.app.wait()
        try? self.elg.syncShutdownGracefully()
    }
}