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

import Foundation

/// It is common for UUID's to be passed in as parameters. So lets add helper
/// functions to extract them from Parameters
extension Parameters {
    /// Return parameter with specified id as a certain type
    /// - Parameters:
    ///   - s: parameter id
    ///   - as: type we want returned
    public func get(_ s: String, as: UUID.Type) -> UUID? {
        return self[s[...]].map { UUID(uuidString: String($0)) } ?? nil
    }

    /// Return parameter with specified id as a certain type
    /// - Parameters:
    ///   - s: parameter id
    ///   - as: type we want returned
    public func require(_ s: String, as: UUID.Type) throws -> UUID {
        guard let param = self[s[...]],
              let result = UUID(uuidString: String(param))
        else {
            throw HTTPError(.badRequest, message: "Parameter '\(s)' can not be converted to the expected type (UUID)")
        }
        return result
    }

    /// Return parameter with specified id as a certain type
    /// - Parameters:
    ///   - s: parameter id
    ///   - as: type we want returned
    public func getAll(_ s: String, as: UUID.Type) -> [UUID] {
        return self[values: s[...]].compactMap { UUID(uuidString: String($0)) }
    }

    /// Return parameter with specified id as a certain type
    /// - Parameters:
    ///   - s: parameter id
    ///   - as: type we want returned
    public func requireAll(_ s: String, as: UUID.Type) throws -> [UUID] {
        return try self[values: s[...]].map {
            guard let result = UUID(uuidString: String($0)) else {
                throw HTTPError(.badRequest, message: "One of the parameters '\(s)' can not be converted to the expected type (UUID)")
            }
            return result
        }
    }
}

extension UUID: ResponseEncodable {}
