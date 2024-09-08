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

import Foundation

extension Character {
    /// A Boolean value indicating whether this is an ASCII number.
    var isASCIINumber: Bool {
        guard isASCII, let value = asciiValue else { return false }
        let asciiNumberRange: ClosedRange<UInt8> = 48...57
        return asciiNumberRange.contains(value)
    }

    /// The ASCII number encoding value of this character, if it is an ASCII number character.
    var asciiNumberValue: Int? {
        guard self.isASCIINumber, let value = asciiValue else { return nil }
        let asciiZeroValue = 48
        // convert ASCII value to number
        return Int(value) - asciiZeroValue
    }
}
