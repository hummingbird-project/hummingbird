//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

/// Errors return by persist framework
public struct PersistError: Error, Equatable {
    private enum Internal {
        case duplicate
        case invalidConversion
    }

    private let value: Internal
    private init(value: Internal) {
        self.value = value
    }

    /// Failed to creating a persist entry as it already exists
    public static var duplicate: Self { .init(value: .duplicate) }
    /// Failed to convert a persist value to the requested type
    public static var invalidConversion: Self { .init(value: .invalidConversion) }
}
