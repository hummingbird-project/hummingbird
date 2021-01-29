import Hummingbird

extension HBApplication {
    public func addFoundation() {
        // Add channel added callback to setup the date cache
        self.addChannelAddedCallback { context in
            self.eventLoopStorage(for: context.eventLoop).dateCache = .init()
        }
        // Add middleware for setting date in the response
        self.middleware.add(HBDateResponseMiddleware())
    }
}
