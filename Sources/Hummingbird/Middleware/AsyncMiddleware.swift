/// Middleware using async/await
public protocol HBAsyncMiddleware: HBMiddleware {
    func apply(to request: HBRequest, next: HBResponder) async throws -> HBResponse
}

extension HBAsyncMiddleware {
    public func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
        @asyncHandler func respond(to request: HBRequest, next: HBResponder, promise: EventLoopPromise<HBResponse>) {
            do {
                let response = try await apply(to: request, next: next)
                promise.succeed(response)
            } catch {
                promise.fail(error)
            }
        }
        let promise = request.eventLoop.makePromise(of: HBResponse.self)
        respond(to: request, next: next, promise: promise)
        return promise.futureResult
    }
}

extension HBResponder {
    /// extend HBResponder to provide async/await version of respond
    public func respond(to request: HBRequest) async throws -> HBResponse {
        return try await respond(to: request).get()
    }

}
