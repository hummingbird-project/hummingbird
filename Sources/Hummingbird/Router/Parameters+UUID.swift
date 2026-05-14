//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

#if canImport(FoundationEssentials)
public import FoundationEssentials
#else
public import Foundation
#endif

/// It is common for UUID's to be passed in as parameters. So lets add helper
/// functions to extract them from Parameters
extension Parameters {
    /// Return parameter with specified id as a certain type
    /// - Parameters:
    ///   - s: parameter id
    ///   - as: type we want returned
    public func get(_ s: String, as: UUID.Type) -> UUID? {
        self[s[...]].map { UUID(uuidString: String($0)) } ?? nil
    }

    /// Return parameter with specified id as a certain type
    /// - Parameters:
    ///   - s: parameter id
    ///   - as: type we want returned
    public func require(_ s: String, as: UUID.Type) throws -> UUID {
        guard let param = self[s[...]] else {
            throw HTTPError(.badRequest, message: "Expected parameter does not exist")
        }
        guard let result = UUID(uuidString: String(param))
        else {
            throw HTTPError(.badRequest, message: "Parameter '\(param)' can not be converted to the expected type (UUID)")
        }
        return result
    }

    /// Return parameter with specified id as a certain type
    /// - Parameters:
    ///   - s: parameter id
    ///   - as: type we want returned
    public func getAll(_ s: String, as: UUID.Type) -> [UUID] {
        self[values: s[...]].compactMap { UUID(uuidString: String($0)) }
    }

    /// Return parameter with specified id as a certain type
    /// - Parameters:
    ///   - s: parameter id
    ///   - as: type we want returned
    public func requireAll(_ s: String, as: UUID.Type) throws -> [UUID] {
        try self[values: s[...]].map {
            guard let result = UUID(uuidString: String($0)) else {
                throw HTTPError(.badRequest, message: "One of the parameters '\($0)' can not be converted to the expected type (UUID)")
            }
            return result
        }
    }
}

extension UUID: ResponseEncodable {}
