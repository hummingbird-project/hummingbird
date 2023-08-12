import HummingbirdCore
import HummingbirdCoreXCT
import NIOCore
import NIOHTTP1
import NIOSSL
import XCTest

public enum TestErrors: Error {
    case timeout
}

/// Basic responder that just returns "Hello" in body
public struct HelloResponder: HBHTTPResponder {
    public func respond(to request: HBHTTPRequest, context: ChannelHandlerContext, onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void) {
        let responseHead = HTTPResponseHead(version: .init(major: 1, minor: 1), status: .ok)
        let responseBody = context.channel.allocator.buffer(string: "Hello")
        let response = HBHTTPResponse(head: responseHead, body: .byteBuffer(responseBody))
        onComplete(.success(response))
    }
}

/// Helper function for test a server
///
/// Creates test client, runs test function abd ensures everything is
/// shutdown correctly
public func testServer(
    _ server: HBHTTPServer,
    clientConfiguration: HBXCTClient.Configuration = .init(),
    _ test: (HBXCTClient) async throws -> Void
) async throws {
    try await server.start()
    let client = await HBXCTClient(
        host: "localhost",
        port: server.port!,
        configuration: clientConfiguration,
        eventLoopGroupProvider: .createNew
    )
    client.connect()
    do {
        try await test(client)
    } catch {
        try await client.shutdown()
        try await server.shutdownGracefully()
        throw error
    }
    try await client.shutdown()
    try await server.shutdownGracefully()
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
