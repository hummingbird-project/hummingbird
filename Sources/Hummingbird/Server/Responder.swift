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

/// Protocol for object that produces a response given a request
///
/// This is the core protocol for Hummingbird. It defines an object that can respond to a request.
public protocol HBResponder {
    /// Return EventLoopFuture that will be fulfilled with response to the request supplied
    func respond(to request: HBRequest, context: HBRequestContext) -> EventLoopFuture<HBResponse>
}

/// Responder that calls supplied closure
public struct HBCallbackResponder: HBResponder {
    let callback: (HBRequest, HBRequestContext) -> EventLoopFuture<HBResponse>

    public init(callback: @escaping (HBRequest, HBRequestContext) -> EventLoopFuture<HBResponse>) {
        self.callback = callback
    }

    /// Return EventLoopFuture that will be fulfilled with response to the request supplied
    public func respond(to request: HBRequest, context: HBRequestContext) -> EventLoopFuture<HBResponse> {
        return self.callback(request, context)
    }
}
