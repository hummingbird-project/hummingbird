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

import NIOCore

/// Middleware implementing Cross-Origin Resource Sharing (CORS) headers.
///
/// If request has "origin" header then generate CORS headers. If method is OPTIONS
/// then return an empty body with all the standard CORS headers otherwise send
/// request onto the next handler and when you receive the response add a
/// "access-control-allow-origin" header
public struct HBCORSMiddleware<Context: HBRequestContext>: HBMiddleware {
    /// Defines what origins are allowed
    public enum AllowOrigin {
        case none
        case all
        case originBased
        case custom(String)

        func value(for request: HBRequest) -> String? {
            switch self {
            case .none:
                return nil
            case .all:
                return "*"
            case .originBased:
                let origin = request.headers["origin"].first
                if origin == "null" { return nil }
                return origin
            case .custom(let value):
                return value
            }
        }
    }

    /// What origins are allowed, header `Access-Control-Allow-Origin`
    let allowOrigin: AllowOrigin
    /// What headers are allowed, header `Access-Control-Allow-Headers`
    let allowHeaders: String
    /// What methods are allowed, header `Access-Control-Allow-Methods`
    let allowMethods: String
    /// Are requests with cookies or an "Authorization" header allowed, header `Access-Control-Allow-Credentials`
    let allowCredentials: Bool
    /// What headers can be exposed back to the browser, header `Access-Control-Expose-Headers`
    let exposedHeaders: String?
    /// how long the results of a pre-flight request can be cached, header `Access-Control-Max-Age`
    let maxAge: String?

    /// Initialize CORS middleware
    ///
    /// - Parameters:
    ///   - allowOrigin: allow origin enum
    ///   - allowHeaders: array of headers that are allowed
    ///   - allowMethods: array of methods that are allowed
    ///   - allowCredentials: are credentials alloed
    ///   - exposedHeaders: array of headers that can be exposed back to the browser
    ///   - maxAge: how long the results of a pre-flight request can be cached
    public init(
        allowOrigin: AllowOrigin = .originBased,
        allowHeaders: [String] = ["accept", "authorization", "content-type", "origin"],
        allowMethods: [HTTPMethod] = [.GET, .POST, .HEAD, .OPTIONS],
        allowCredentials: Bool = false,
        exposedHeaders: [String]? = nil,
        maxAge: TimeAmount? = nil
    ) {
        self.allowOrigin = allowOrigin
        self.allowHeaders = allowHeaders.joined(separator: ", ")
        self.allowMethods = allowMethods.map(\.rawValue).joined(separator: ", ")
        self.allowCredentials = allowCredentials
        self.exposedHeaders = exposedHeaders?.joined(separator: ", ")
        self.maxAge = maxAge.map { String(describing: $0.nanoseconds / 1_000_000_000) }
    }

    /// apply CORS middleware
    public func apply(to request: HBRequest, context: Context, next: any HBResponder<Context>) -> EventLoopFuture<HBResponse> {
        // if no origin header then don't apply CORS
        guard request.headers["origin"].first != nil else { return next.respond(to: request, context: context) }

        if request.method == .OPTIONS {
            // if request is OPTIONS then return CORS headers and skip the rest of the middleware chain
            var headers: HTTPHeaders = [
                "access-control-allow-origin": allowOrigin.value(for: request) ?? "",
            ]
            headers.add(name: "access-control-allow-headers", value: self.allowHeaders)
            headers.add(name: "access-control-allow-methods", value: self.allowMethods)
            if self.allowCredentials {
                headers.add(name: "access-control-allow-credentials", value: "true")
            }
            if let maxAge = self.maxAge {
                headers.add(name: "access-control-max-age", value: maxAge)
            }
            if let exposedHeaders = self.exposedHeaders {
                headers.add(name: "access-control-expose-headers", value: exposedHeaders)
            }
            if case .originBased = self.allowOrigin {
                headers.add(name: "vary", value: "Origin")
            }

            return context.success(HBResponse(status: .noContent, headers: headers, body: .empty))
        } else {
            // if not OPTIONS then run rest of middleware chain and add origin value at the end
            return next.respond(to: request, context: context).map { response in
                var response = response
                response.headers.add(name: "access-control-allow-origin", value: self.allowOrigin.value(for: request) ?? "")
                if self.allowCredentials {
                    response.headers.add(name: "access-control-allow-credentials", value: "true")
                }
                if case .originBased = self.allowOrigin {
                    response.headers.add(name: "vary", value: "Origin")
                }
                return response
            }
        }
    }
}
