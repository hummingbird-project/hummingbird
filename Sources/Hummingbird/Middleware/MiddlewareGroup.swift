import NIO

public class HBMiddlewareGroup {
    var middlewares: [HBMiddleware]

    init() {
        self.middlewares = []
    }

    public func add(_ middleware: HBMiddleware) {
        self.middlewares.append(middleware)
    }

    public func constructResponder(finalResponder: HBResponder) -> HBResponder {
        var currentResponser = finalResponder
        for i in (0..<self.middlewares.count).reversed() {
            let responder = MiddlewareResponder(middleware: middlewares[i], next: currentResponser)
            currentResponser = responder
        }
        return currentResponser
    }
}
