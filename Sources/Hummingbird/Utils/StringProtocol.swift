//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

extension StringProtocol {
    func dropSuffix(_ suffix: String) -> Self.SubSequence {
        if hasSuffix(suffix) {
            return self.dropLast(suffix.count)
        } else {
            return self[...]
        }
    }
}
