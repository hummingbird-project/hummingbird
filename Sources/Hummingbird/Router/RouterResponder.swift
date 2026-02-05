//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import NIOCore

public struct RouterResponder<Context: RequestContext>: HTTPResponder {
    @usableFromInline
    let trie: RouterTrie<EndpointResponders<Context>>

    @usableFromInline
    let notFoundResponder: any HTTPResponder<Context>

    @usableFromInline
    let options: RouterOptions

    init(
        context: Context.Type,
        trie: RouterPathTrieBuilder<EndpointResponders<Context>>,
        options: RouterOptions,
        notFoundResponder: any HTTPResponder<Context>
    ) {
        self.trie = RouterTrie(base: trie, options: options)
        self.options = options
        self.notFoundResponder = notFoundResponder
    }

    /// Respond to request by calling correct handler
    /// - Parameters
    ///   - request: HTTP request
    ///   - context: Request context
    /// - Returns: Response
    @inlinable
    public func respond(to request: Request, context: Context) async throws -> Response {
        do {
            let path = request.uri.path
            guard
                let (responderChain, parameters) = trie.resolve(path),
                let responder = responderChain.getResponder(for: request.method)
            else {
                return try await self.notFoundResponder.respond(to: request, context: context)
            }
            var context = context
            context.coreContext.parameters = parameters
            // store endpoint path in request (mainly for metrics)
            context.coreContext.endpointPath.value = responderChain.path.description
            return try await responder.respond(to: request, context: context)
        } catch let error as any HTTPResponseError {
            return try error.response(from: request, context: context)
        }
    }
}
