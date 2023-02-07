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

extension StringProtocol {
    func dropPrefix(_ prefix: String) -> Self.SubSequence {
        if hasPrefix(prefix) {
            return self.dropFirst(prefix.count)
        } else {
            return self[...]
        }
    }

    func dropSuffix(_ suffix: String) -> Self.SubSequence {
        if hasSuffix(suffix) {
            return self.dropLast(suffix.count)
        } else {
            return self[...]
        }
    }
}
