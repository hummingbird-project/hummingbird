import HummingbirdCore
import HummingbirdRouter
import NIOCore
import Logging

/// Protocol for a request context that can be created from a NIO Channel
public protocol HBRequestContext: HBRouterRequestContext {
    var applicationContext: HBApplicationContext { get }

    /// initialize an `HBRequestContext`
    /// - Parameters:
    ///   - applicationContext: Context coming from Application
    ///   - channel: Channel that created request and context
    ///   - logger: Logger to use with request
    init(applicationContext: HBApplicationContext, configuration: HBRequestContextConfiguration, channel: Channel, logger: Logger)
}

/// Implementation of a basic request context that supports everything the Hummingbird library needs
public struct HBBasicRequestContext: HBRequestContext {
    /// Parameters extracted from URI
    public var parameters: HBParameters

    public let applicationContext: HBApplicationContext

    /// core context
    public var coreContext: HBCoreRequestContext

    ///  Initialize an `HBRequestContext`
    /// - Parameters:
    ///   - applicationContext: Context from Application that instigated the request
    ///   - source: Source of request context
    ///   - logger: Logger
    public init(
        applicationContext: HBApplicationContext,
        configuration: HBRequestContextConfiguration,
        channel: Channel,
        logger: Logger
    ) {
        self.parameters = .init()
        self.applicationContext = applicationContext
        self.coreContext = .init(
            configuration: configuration,
            eventLoop: channel.eventLoop,
            allocator: channel.allocator,
            logger: logger
        )
    }
}
