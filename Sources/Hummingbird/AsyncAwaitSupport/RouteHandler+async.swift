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

#if compiler(>=5.5.2) && canImport(_Concurrency)

/// Route Handler using async/await methods
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public protocol HBAsyncRouteHandler: HBRouteHandler where _Output == EventLoopFuture<_Output2> {
    associatedtype _Output2
    init(from: HBRequest) throws
    func handle(request: HBRequest) async throws -> _Output2
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension HBAsyncRouteHandler {
    public func handle(request: HBRequest) throws -> EventLoopFuture<_Output2> {
        let promise = request.eventLoop.makePromise(of: _Output2.self)
        promise.completeWithTask {
            try await handle(request: request)
        }
        return promise.futureResult
    }
}

#endif // compiler(>=5.5) && canImport(_Concurrency)
