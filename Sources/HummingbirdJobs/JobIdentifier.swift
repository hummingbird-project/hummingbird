//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// Identifier for a Job type
///
/// The identifier includes the type of the parameters required by the job to ensure
/// the wrong parameters are not passed to this job
///
/// Extend this type to include your own job identifiers
/// ```
/// extension HBJobIdentifier<String> {
///     static var myJob: Self { .init("my-job") }
/// }
/// ```
public struct HBJobIdentifier<Parameters>: Sendable, Hashable, ExpressibleByStringLiteral {
    let name: String
    /// Initialize a HBJobIdentifier
    ///
    /// - Parameters:
    ///   - name: Unique name for identifier
    ///   - parameters: Parameter type associated with Job
    public init(_ name: String, parameters: Parameters.Type = Parameters.self) { self.name = name }

    /// Initialize a HBJobIdentifier from a string literal
    ///
    /// This can only be used in a situation where the Parameter type is defined elsewhere
    /// - Parameter string:
    public init(stringLiteral string: String) {
        self.name = string
    }
}
