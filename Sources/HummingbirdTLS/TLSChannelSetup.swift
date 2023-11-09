import HummingbirdCore
import Logging
import NIOCore
import NIOHTTP1
import NIOSSL

/// Setup child channel for HTTP1 with TLS
public struct HTTP1WithTLSChannel: HBChannelSetup, HTTPChannelHandler {
    public typealias Value = NIOAsyncChannel<HTTPServerRequestPart, SendableHTTPServerResponsePart>

    public init(
        tlsConfiguration: TLSConfiguration,
        additionalChannelHandlers: @autoclosure @escaping @Sendable () -> [any RemovableChannelHandler] = [],
        responder: @escaping @Sendable (HBHTTPRequest, Channel) async throws -> HBHTTPResponse = { _, _ in throw HBHTTPError(.notImplemented) }
    ) throws {
        var tlsConfiguration = tlsConfiguration
        tlsConfiguration.applicationProtocols.append("http/1.1")
        self.sslContext = try NIOSSLContext(configuration: tlsConfiguration)
        self.additionalChannelHandlers = additionalChannelHandlers
        self.responder = responder
    }

    public func initialize(channel: Channel, configuration: HBServerConfiguration, logger: Logger) -> EventLoopFuture<Value> {
        let childChannelHandlers: [RemovableChannelHandler] = self.additionalChannelHandlers() + [
            HBHTTPUserEventHandler(logger: logger),
            HBHTTPSendableResponseChannelHandler(),
        ]
        return channel.eventLoop.makeCompletedFuture {
            try channel.pipeline.syncOperations.addHandler(NIOSSLServerHandler(context: self.sslContext))
            try channel.pipeline.syncOperations.configureHTTPServerPipeline(
                withPipeliningAssistance: false,
                withErrorHandling: true
            )
            try channel.pipeline.syncOperations.addHandlers(childChannelHandlers)
            return try NIOAsyncChannel(
                synchronouslyWrapping: channel,
                configuration: .init()
            )
        }
    }

    public func handle(value asyncChannel: NIOCore.NIOAsyncChannel<NIOHTTP1.HTTPServerRequestPart, SendableHTTPServerResponsePart>, logger: Logging.Logger) async {
        await handleHTTP(asyncChannel: asyncChannel, logger: logger)
    }

    public var responder: @Sendable (HBHTTPRequest, Channel) async throws -> HBHTTPResponse
    let sslContext: NIOSSLContext
    let additionalChannelHandlers: @Sendable () -> [any RemovableChannelHandler]
}
