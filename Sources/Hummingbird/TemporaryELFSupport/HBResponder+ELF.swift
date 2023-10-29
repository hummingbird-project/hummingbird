import NIOCore

extension HBResponder {
    @available(*, noasync)
    public func respond(to request: HBRequest, context: Context) -> EventLoopFuture<HBResponse> {
        context.eventLoop.makeFutureWithTask {
            try await self.respond(to: request, context: context)
        }
    }
}