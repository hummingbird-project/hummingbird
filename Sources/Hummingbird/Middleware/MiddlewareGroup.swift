import NIO

/// Group of middleware that can be used to create a responder chain. Each middleware calls the next one
public class HBMiddlewareGroup {
    var middlewares: [HBMiddleware]

    init() {
        self.middlewares = []
    }

    /// Add middleware to group
    public func add(_ middleware: HBMiddleware) {
        self.middlewares.append(middleware)
    }

    /// Construct responder chain from this middleware group
    /// - Parameter finalResponder: The responder the last middleware calls
    /// - Returns: Responder chain
    public func constructResponder(finalResponder: HBResponder) -> HBResponder {
        var currentResponser = finalResponder
        for i in (0..<self.middlewares.count).reversed() {
            let responder = MiddlewareResponder(middleware: middlewares[i], next: currentResponser)
            currentResponser = responder
        }
        return currentResponser
    }
}
