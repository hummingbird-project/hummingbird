//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import HTTPTypes

/// Stores endpoint responders for each HTTP method
struct EndpointResponders<Context: BaseRequestContext>: Sendable {
    init(path: String) {
        self.path = path
        self.methods = [:]
    }

    public func getResponder(for method: HTTPRequest.Method) -> (any HTTPResponder<Context>)? {
        return self.methods[method]
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
                var response = try await get.respond(to: request, context: context)
                response.body = .init()
                return response
            }
        }
    }

    var methods: [HTTPRequest.Method: any HTTPResponder<Context>]
    var path: String
}
