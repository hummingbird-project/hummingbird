//===----------------------------------------------------------------------===//
//
// This source file is part of the Soto for AWS open source project
//
// Copyright (c) 2017-2020 the Soto project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Soto project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

internal enum Environment {
    internal static subscript(_ name: String) -> String? {
        get {
            guard let value = getenv(name) else {
                return nil
            }
            return String(cString: value)
        }
        set {
            if let value = newValue {
                setenv(name, value, 1)
            } else {
                unsetenv(name)
            }
        }
    }

    internal static subscript(int name: String) -> Int? {
        guard let value = getenv(name) else {
            return nil
        }
        let string = String(cString: value)
        return Int(string)
    }
}
