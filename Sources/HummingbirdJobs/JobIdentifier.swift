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
public struct HBJobIdentifier<Parameters>: Sendable, Hashable {
    let name: String
    public init(_ name: String, parameters: Parameters.Type = Parameters.self) { self.name = name }
}
