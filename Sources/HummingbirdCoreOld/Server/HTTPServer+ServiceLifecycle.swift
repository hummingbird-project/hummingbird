import ServiceLifecycle

extension HBHTTPServer: Service {
    public func run() async throws {
        try await self.start()

        try await withGracefulShutdownHandler {
            try await self.wait()
        } onGracefulShutdown: {
            Task {
                do {
                    try await self.shutdownGracefully()
                } catch {
                    self.logger.error("Server shutdown error: \(error)")
                }
            }
        }
    }
}
