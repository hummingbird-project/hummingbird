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

import NIOCore
import NIOHTTP1

/// Stores endpoint responders for each HTTP method
final class HBEndpointResponders<Context: HBRequestContext> {
    init(path: String) {
        self.path = path
        self.methods = [:]
    }

    public func getResponder(for method: HTTPMethod) -> (any HBResponder<Context>)? {
        return self.methods[method.rawValue]
    }

    func addResponder(for method: HTTPMethod, responder: any HBResponder<Context>) {
        guard self.methods[method.rawValue] == nil else {
            preconditionFailure("\(method.rawValue) already has a handler")
        }
        self.methods[method.rawValue] = responder
    }

    var methods: [String: any HBResponder<Context>]
    var path: String
}
