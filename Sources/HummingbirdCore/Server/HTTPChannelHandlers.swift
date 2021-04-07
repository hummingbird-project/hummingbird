import NIO

/// Stores channel handlers used in HTTP server
struct HBHTTPChannelHandlers {
    /// Initialize `HBHTTPChannelHandlers`
    public init() {
        self.handlers = []
    }

    /// Add autoclosure that creates a ChannelHandler
    public mutating func addHandler(_ handler: @autoclosure @escaping () -> RemovableChannelHandler) {
        self.handlers.append(handler)
    }

    /// Return array of ChannelHandlers
    public func getHandlers() -> [RemovableChannelHandler] {
        return self.handlers.map { $0() }
    }

    private var handlers: [() -> RemovableChannelHandler]
}
