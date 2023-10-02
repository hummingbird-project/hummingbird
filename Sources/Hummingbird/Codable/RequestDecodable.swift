//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

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
    public init(from request: HBRequest, context: HBRequestContext) throws {
        self = try request.decode(as: Self.self, using: context)
    }
}
