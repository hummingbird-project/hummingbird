//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import HTTPTypes

/// Middleware for setting up content-security-policy related response headers
///
/// Currently sets headers `content-security-policy`, `x-content-type-options`
/// and optionally sets `content-security-policy-report-only` and `reporting-endpoints`.
public struct ContentSecurityMiddleware<Context: RequestContext>: RouterMiddleware {
    let headers: HTTPFields

    /// Initialize the SecurityMiddleware
    ///
    /// - Parameters:
    ///   - contentSecurityPolicy: Set `content-security-policy` header. Defines access to resources, from served HTML pages.
    ///   - contentSecurityPolicyReportOnly: Set `content-security-policy-report-only` header. Reports access to resources, from served HTML pages.
    ///   - reportingEndpoints: Set `reporting-endpoints` header. If you are using content security policy directive `report-to` you
    ///         can use this to define your reporting endpoints.
    public init(
        contentSecurityPolicy: ContentSecurityPolicy = [
            .defaultSrc(.self),
            .formAction(.self),
            .frameAncestors(.self),
        ],
        contentSecurityPolicyReportOnly: ContentSecurityPolicy? = nil,
        reportingEndpoints: [String: String]? = nil
    ) {
        var headers: HTTPFields = [
            .contentSecurityPolicy: contentSecurityPolicy.description,
            .xContentTypeOptions: "nosniff",
        ]
        if let contentSecurityPolicyReportOnly {
            headers[.contentSecurityPolicyReportOnly] = contentSecurityPolicyReportOnly.description
        }
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
