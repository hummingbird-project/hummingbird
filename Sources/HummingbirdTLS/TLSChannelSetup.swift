import HummingbirdCore
import Logging
import NIOCore
import NIOSSL

/// Sets up child channel to use TLS before accessing base channel setup
public struct TLSChannel<BaseChannel: HBChannelSetup>: HBChannelSetup {
    public typealias Value = BaseChannel.Value

    public init(_ baseChannel: BaseChannel, tlsConfiguration: TLSConfiguration) throws {
        self.sslContext = try NIOSSLContext(configuration: tlsConfiguration)
        self.baseChannel = baseChannel
    }

    @inlinable
    public func initialize(channel: Channel, configuration: HBServerConfiguration, logger: Logger) -> EventLoopFuture<Value> {
        return channel.pipeline.addHandler(NIOSSLServerHandler(context: self.sslContext)).flatMap {
            self.baseChannel.initialize(channel: channel, configuration: configuration, logger: logger)
        }
    }

    @inlinable
    public func handle(value: BaseChannel.Value, logger: Logging.Logger) async {
        await self.baseChannel.handle(value: value, logger: logger)
    }

    @usableFromInline
    let sslContext: NIOSSLContext
    @usableFromInline
    var baseChannel: BaseChannel
}

extension TLSChannel: HTTPChannelHandler where BaseChannel: HTTPChannelHandler {
    public var responder: @Sendable (HBRequest, Channel) async throws -> HBResponse {
        get { baseChannel.responder }
        set { baseChannel.responder = newValue }
    }
}
