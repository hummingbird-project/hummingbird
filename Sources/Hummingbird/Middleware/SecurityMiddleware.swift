//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import HTTPTypes

/// Middleware for setting up various security related response headers
///
/// Currently sets headers `content-security-policy`, `cross-origin-resource-policy`, `x-content-type-options`
/// and optionally sets `reporting-endpoints`.
public struct SecurityMiddleware<Context: RequestContext>: RouterMiddleware {
    let headers: HTTPFields

    /// Let websites and applications opt-in to protection against vulnerabilities related to certain
    /// cross-origin requests. As the policy is expressed by a response header it relies on the browser
    /// to strip the response body
    public struct CrossOriginResourcePolicy: Sendable {
        @usableFromInline
        enum Internal: String, Sendable {
            case sameOrigin = "same-origin"
            case sameSite = "same-site"
            case crossOrigin = "cross-origin"
        }
        @usableFromInline
        let value: Internal
        @usableFromInline
        init(value: Internal) {
            self.value = value
        }

        /// Limits resource access to requests coming from the same origin.
        @inlinable public static var sameOrigin: Self { .init(value: .sameOrigin) }
        /// Limits resource access to requests coming from the same site.
        @inlinable public static var sameSite: Self { .init(value: .sameSite) }
        /// Allows resources to be accessed by cross-origin requests.
        @inlinable public static var crossOrigin: Self { .init(value: .crossOrigin) }
    }

    /// Initialize the SecurityMiddleware
    ///
    /// - Parameters:
    ///   - contentSecurityPolicy: Set `content-security-policy` header. Defines access to website resources.
    ///   - crossOriginResourcePolicy: Set `cross-origin-resource-policy` header. Defines whether browser should drop body.
    ///   - reportingEndpoints: Set `reporting-endpoints` header. If you are using content security policy directive `report-to` you
    ///         can use this to define your reporting endpoints.
    public init(
        contentSecurityPolicy: ContentSecurityPolicy = [
            .defaultSrc(.self),
            .formAction(.self),
            .frameAncestors(.self),
        ],
        crossOriginResourcePolicy: CrossOriginResourcePolicy = .sameSite,
        reportingEndpoints: [String: String]? = nil
    ) {
        var headers: HTTPFields = [
            .crossOriginResourcePolicy: crossOriginResourcePolicy.value.rawValue,
            .contentSecurityPolicy: contentSecurityPolicy.description,
            .xContentTypeOptions: "nosniff",
        ]
        if let reportingEndpoints {
            headers[HTTPField.Name("Reporting-Endpoints")!] = reportingEndpoints.map { "\($0.key)=\"\($0.value)\"" }.joined(separator: ",")
        }
        self.headers = headers
    }

    public func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        var response = try await next(request, context)
        response.headers.append(contentsOf: headers)
        return response
    }
}
