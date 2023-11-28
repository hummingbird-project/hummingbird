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
struct HBEndpointResponders<Context: HBBaseRequestContext>: Sendable {
    init(path: String) {
        self.path = path
        self.methods = [:]
    }

    public func getResponder(for method: HTTPRequest.Method) -> (any HBResponder<Context>)? {
        return self.methods[method.rawValue]
    }

    mutating func addResponder(for method: HTTPRequest.Method, responder: any HBResponder<Context>) {
        guard self.methods[method.rawValue] == nil else {
            preconditionFailure("\(method.rawValue) already has a handler")
        }
        self.methods[method.rawValue] = responder
    }

    var methods: [String: any HBResponder<Context>]
    var path: String
}
