import Hummingbird
import HummingbirdCoreXCT
import NIO

func run(identifier: String) {
    measure(identifier: identifier) {
        let iterations = 100
        for _ in 0..<iterations {
            let app = HBApplication(
                configuration: .init(logLevel: .error), 
                eventLoopGroupProvider: .createNew
            )
            app.router.get("/") { _ in
                return "ok"
            }
            try? app.start()
            app.stop()
            app.wait()
        }
        return iterations
    }
}

