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
/// Conforms to `Responder` so need to provide its own implementation of
/// `func respond(to request: Request, context: Context) async throws -> Response`.
///
public struct RouterResponder<Context: BaseRequestContext>: HTTPResponder {
    let trie: RouterPathTrie<EndpointResponders<Context>>
    let notFoundResponder: any HTTPResponder<Context>
    let options: RouterOptions

    init(
        context: Context.Type,
        trie: RouterPathTrie<EndpointResponders<Context>>,
        options: RouterOptions,
        notFoundResponder: any HTTPResponder<Context>
    ) {
        self.trie = trie
        self.options = options
        self.notFoundResponder = notFoundResponder
    }

    /// Respond to request by calling correct handler
    /// - Parameter request: HTTP request
    /// - Returns: EventLoopFuture that will be fulfilled with the Response
    public func respond(to request: Request, context: Context) async throws -> Response {
        let path: String
        if self.options.contains(.caseInsensitive) {
            path = request.uri.path.lowercased()
        } else {
            path = request.uri.path
        }
        guard let result = trie.getValueAndParameters(path),
              let responder = result.value.getResponder(for: request.method)
        else {
            return try await self.notFoundResponder.respond(to: request, context: context)
        }
        var context = context
        if let parameters = result.parameters {
            context.coreContext.parameters = parameters
        }
        // store endpoint path in request (mainly for metrics)
        context.coreContext.endpointPath.value = result.value.path
        return try await responder.respond(to: request, context: context)
    }
}
