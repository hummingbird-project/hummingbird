import Hummingbird

extension HBApplication {
    /// Add additional functionality that comes with Foundation
    ///
    /// Currently this is the current date cache and the "Date" header in the reponse
    public func addFoundation() {
        self.addDateCaches()
        // Add middleware for setting date in the response
        self.middleware.add(HBDateResponseMiddleware())
    }
}
