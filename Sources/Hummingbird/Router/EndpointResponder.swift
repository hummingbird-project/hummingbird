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
final class HBEndpointResponders {
    init(path: String) {
        self.path = path
        self.methods = [:]
    }

    public func getResponder(for method: HTTPMethod) -> HBResponder? {
        return methods[method.rawValue]
    }

    func addResponder(for method: HTTPMethod, responder: HBResponder) {
        guard self.methods[method.rawValue] == nil else {
            preconditionFailure("\(method.rawValue) already has a handler")
        }
        self.methods[method.rawValue] = responder
    }

    var methods: [String: HBResponder]
    var path: String
}
