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

import Foundation

/// Identifier for Job
public struct JobIdentifier: Sendable, CustomStringConvertible, Codable, Hashable {
    let id: String

    init() {
        self.id = UUID().uuidString
    }

    /// Initialize JobIdentifier from String
    /// - Parameter value: string value
    public init(_ value: String) {
        self.id = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.id = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.id)
    }

    /// String description of Identifier
    public var description: String { self.id }
}
