//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

/// A type that can be initialized from another type
public protocol InitializableFromSource<Source>: Sendable {
    associatedtype Source
    /// Initialise from source type
    init(source: Source)
}
