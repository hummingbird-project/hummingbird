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

/// Directs requests to handlers based on the request uri and method.
///
/// Conforms to `HBResponder` so need to provide its own implementation of
/// `func apply(to request: Request) -> EventLoopFuture<Response>`.
///
struct HBRouter: HBResponder {
    let trie: RouterPathTrie<HBEndpointResponders>
    let notFoundResponder: HBResponder

    /// Respond to request by calling correct handler
    /// - Parameter request: HTTP request
    /// - Returns: EventLoopFuture that will be fulfilled with the Response
    public func respond(to request: HBRequest) -> EventLoopFuture<HBResponse> {
        let path = request.uri.path
        guard let result = trie.getValueAndParameters(path),
              let responder = result.value.getResponder(for: request.method)
        else {
            return self.notFoundResponder.respond(to: request)
        }
        var request = request
        if let parameters = result.parameters {
            request.parameters = parameters
        }
        // store endpoint path in request (mainly for metrics)
        request.endpointPath = result.value.path
        return responder.respond(to: request)
    }
}
