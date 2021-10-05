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
import NIOHTTP1

/// Responder that chooses the next responder to call based on the request method
final class HBEndpointResponder: HBResponder {
    init(path: String) {
        self.path = path
        self.methods = [:]
    }

    public func respond(to request: HBRequest) -> EventLoopFuture<HBResponse> {
        guard let responder = methods[request.method.rawValue] else {
            return request.failure(HBHTTPError(.notFound))
        }
        return responder.respond(to: request)
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
