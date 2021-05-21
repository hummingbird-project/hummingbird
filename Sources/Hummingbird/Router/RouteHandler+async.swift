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

#if compiler(>=5.5) && $AsyncAwait

@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
public protocol HBAsyncRouteHandler: HBRouteHandler where _Output == EventLoopFuture<_Output2> {
    associatedtype _Output2
    init(from: HBRequest) throws
    func handle(request: HBRequest) async throws -> _Output2
}

@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
extension HBAsyncRouteHandler {
    public func handle(request: HBRequest) throws -> EventLoopFuture<_Output2> {
        let promise = request.eventLoop.makePromise(of: _Output2.self)
        promise.completeWithAsync {
            try await handle(request: request)
        }
        return promise.futureResult
    }
}

#endif // compiler(>=5.5) && $AsyncAwait
