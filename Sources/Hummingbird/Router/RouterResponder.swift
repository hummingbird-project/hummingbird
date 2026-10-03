//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import HTTPAPIs
import HummingbirdCore
import NIOCore

@available(hummingbird 3.0, *)
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

    /// Respond to the request supplied
    public func respond(to request: Request, writer: consuming some (ResponseWriter & ~Copyable), context: Context) async throws {
        let writer = BoxedResponseWriter(writer: writer)
        do {
            let path = request.uri.path
            guard
                let (responderChain, parameters) = trie.resolve(path),
                let responder = responderChain.getResponder(for: request.method)
            else {
                return try await self.notFoundResponder.respond(to: request, writer: writer, context: context)
            }
            var context = context
            context.coreContext.parameters = parameters
            // store endpoint path in request (mainly for metrics)
            context.coreContext.endpointPath.value = responderChain.path.description
            try await responder.respond(to: request, writer: writer, context: context)
        } catch let error as any HTTPResponseError {
            if let writer = writer.take() {
                try await error.writeResponse(from: request, writer: writer, context: context)
            }
        } catch {
            if let writer = writer.take() {
                try await writer.sendAndFinish(.init(status: .internalServerError))
            }
        }
    }
}
