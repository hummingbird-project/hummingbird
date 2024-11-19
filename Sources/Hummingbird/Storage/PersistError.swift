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

/// Errors return by persist framework
public struct PersistError: Error, Equatable {
    private enum Internal {
        case duplicate
        case invalidType
    }

    private let value: Internal
    private init(value: Internal) {
        self.value = value
    }

    /// Failed to creating a persist entry as it already exists
    public static var duplicate: Self { .init(value: .duplicate) }
    /// Failed to convert a persist value to the requested type
    public static var invalidType: Self { .init(value: .invalidType) }
}
