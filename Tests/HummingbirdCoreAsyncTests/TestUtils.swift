import HummingbirdCoreAsync
import HummingbirdCoreXCT
import Logging
import NIOCore
import NIOHTTP1
import NIOSSL
import ServiceLifecycle
import XCTest

public enum TestErrors: Error {
    case timeout
}

/// Basic responder that just returns "Hello" in body
@Sendable public func helloResponder(to request: HBHTTPRequest, channel: Channel) async -> HBHTTPResponse {
    let responseBody = channel.allocator.buffer(string: "Hello")
    return HBHTTPResponse(status: .ok, body: .init(byteBuffer: responseBody))
}

/// Helper function for test a server
///
/// Creates test client, runs test function abd ensures everything is
/// shutdown correctly
public func testServer<ChannelSetup: HBChannelSetup>(
    childChannelSetup: ChannelSetup,
    configuration: HBServerConfiguration,
    eventLoopGroup: EventLoopGroup,
    logger: Logger,
    clientConfiguration: HBXCTClient.Configuration = .init(),
    _ test: @escaping @Sendable (HBXCTClient) async throws -> Void
) async throws {
    try await withThrowingTaskGroup(of: Void.self) { group in
        let promise = Promise<Int>()
        let server = HBServer(
            childChannelSetup: childChannelSetup,
            configuration: configuration,
            onServerRunning: { await promise.complete($0.localAddress!.port!) },
            eventLoopGroup: eventLoopGroup,
            logger: logger
        )
        let serviceGroup = ServiceGroup(
            configuration: .init(
                services: [server],
                gracefulShutdownSignals: [.sigterm, .sigint],
                logger: logger
            )
        )
        group.addTask {
            try await serviceGroup.run()
        }
        let client = await HBXCTClient(
            host: "localhost",
            port: promise.wait(),
            configuration: clientConfiguration,
            eventLoopGroupProvider: .createNew
        )
        group.addTask {
            client.connect()
            try await test(client)
        }
        var iterator = group.makeAsyncIterator()
        do {
            try await iterator.next()
        } catch {}
        await serviceGroup.triggerGracefulShutdown()
        try await client.shutdown()
    }
}

/// Run process with a timeout
/// - Parameters:
///   - timeout: Amount of time before timeout error is thrown
///   - process: Process to run
public func withTimeout(_ timeout: TimeAmount, _ process: @escaping @Sendable () async throws -> Void) async throws {
    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await Task.sleep(nanoseconds: numericCast(timeout.nanoseconds))
            throw TestErrors.timeout
        }
        group.addTask {
            try await process()
        }
        try await group.next()
        group.cancelAll()
    }
}

/// Promise type.
actor Promise<Value> {
    enum State {
        case blocked([CheckedContinuation<Value, Never>])
        case unblocked(Value)
    }

    var state: State

    init() {
        self.state = .blocked([])
    }

    /// wait from promise to be completed
    func wait() async -> Value {
        switch self.state {
        case .blocked(var continuations):
            return await withCheckedContinuation { cont in
                continuations.append(cont)
                self.state = .blocked(continuations)
            }
        case .unblocked(let value):
            return value
        }
    }

    /// complete promise with value
    func complete(_ value: Value) {
        switch self.state {
        case .blocked(let continuations):
            for cont in continuations {
                cont.resume(returning: value)
            }
            self.state = .unblocked(value)
        case .unblocked:
            break
        }
    }
}
