/// `HBRouteHandler` which uses `Codable` to initialize it
///
/// An example
/// ```
/// struct CreateUser: HBRequestDecodable {
///     let username: String
///     let password: String
///     func handle(request: HBRequest) -> EventLoopFuture<HTTPResponseStatus> {
///         return addUserToDatabase(
///             name: self.username,
///             password: self.password
///         ).map { _ in .ok }
/// }
/// application.router.put("user", use: CreateUser.self)
///
public protocol HBRequestDecodable: HBRouteHandler, Decodable {}

extension HBRequestDecodable {
    /// Create using `Codable` interfaces
    /// - Parameter request: request
    /// - Throws: HBHTTPError
    public init(from request: HBRequest) throws {
        self = try request.decode(as: Self.self)
    }
}
