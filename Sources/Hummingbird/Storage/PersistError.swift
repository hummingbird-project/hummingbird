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
public struct HBPersistError: Error, Equatable {
    private enum Internal {
        case duplicate
    }

    private let value: Internal
    private init(value: Internal) {
        self.value = value
    }

    public static var duplicate: Self { .init(value: .duplicate) }
}
