//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
import Logging

/// A RequestContext that can be initialized from another RequestContext but
/// the initialization might fail
public protocol ChildRequestContext<ParentContext>: RequestContext where Source == Never {
    associatedtype ParentContext: RequestContext
    /// Initialise RequestContext from source
    init(context: ParentContext) throws
}

extension ChildRequestContext {
    /// ChildRequestContext can never to created from it Source ``Never`` so add preconditionFailure
    public init(source: Source) {
        preconditionFailure("Cannot reach this.")
    }
}

/// Extend Never to conform to ``RequestContextSource``
extension Never: RequestContextSource {
    public var logger: Logger {
        preconditionFailure("Cannot reach this.")
    }
}
