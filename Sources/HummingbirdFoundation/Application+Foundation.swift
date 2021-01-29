import Hummingbird

extension HBApplication {
    public func addFoundation() {
        self.addDateCaches()
        // Add middleware for setting date in the response
        self.middleware.add(HBDateResponseMiddleware())
    }
}
