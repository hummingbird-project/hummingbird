//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

public import HTTPTypes

/// Stores endpoint responders for each HTTP method
@available(macOS 14, iOS 17, tvOS 17, *)
@usableFromInline
struct EndpointResponders<Context>: Sendable {
    init(path: RouterPath) {
        self.path = path
        self.methods = [:]
    }

    @inlinable
    public func getResponder(for method: __shared HTTPRequest.Method) -> (any HTTPResponder<Context>)? {
        self.methods[method]
    }

    mutating func addResponder(for method: HTTPRequest.Method, responder: any HTTPResponder<Context>) {
        guard self.methods[method] == nil else {
            preconditionFailure("\(method.rawValue) already has a handler")
        }
        self.methods[method] = responder
    }

    mutating func autoGenerateHeadEndpoint() {
        if self.methods[.head] == nil, let get = methods[.get] {
            self.methods[.head] = CallbackResponder { request, context in
                let response = try await get.respond(to: request, context: context)
                return response.createHeadResponse()
            }
        }
    }

    @usableFromInline
    var methods: [HTTPRequest.Method: any HTTPResponder<Context>]

    @usableFromInline
    var path: RouterPath
}
