import NIO

public class MiddlewareGroup {
    var middlewares: [Middleware]
    
    init() {
        middlewares = []
    }
    
    public func add(_ middleware: Middleware) {
        middlewares.append(middleware)
    }
    
    public func constructResponder(finalResponder: Responder) -> Responder {
        var currentResponser = finalResponder
        for i in (0..<middlewares.count).reversed() {
            let responder = MiddlewareResponder(middleware: middlewares[i], next: currentResponser)
            currentResponser = responder
        }
        return currentResponser
    }
}
