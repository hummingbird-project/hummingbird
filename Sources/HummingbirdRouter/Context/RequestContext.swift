import HummingbirdCore
import NIOCore
import Logging

public protocol HBRouterRequestContext: HBBaseRequestContext {
    /// Parameters extracted from URI
    var parameters: HBParameters { get set }
}