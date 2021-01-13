import NIO

public class MiddlewareGroup {
    var middlewares: [Middleware]

    init() {
        self.middlewares = []
    }

    public func add(_ middleware: Middleware) {
        self.middlewares.append(middleware)
    }

    public func constructResponder(finalResponder: RequestResponder) -> RequestResponder {
        var currentResponser = finalResponder
        for i in (0..<self.middlewares.count).reversed() {
            let responder = MiddlewareResponder(middleware: middlewares[i], next: currentResponser)
            currentResponser = responder
        }
        return currentResponser
    }
}
