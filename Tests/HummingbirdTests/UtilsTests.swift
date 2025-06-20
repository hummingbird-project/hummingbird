//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import HummingbirdCore
import Testing

struct UtilsTests {
    struct FlatDictionaryTests {
        @Test func testLiteralInit() {
            let a: FlatDictionary<String, String> = ["test": "value", "key2": "value2"]
            #expect(a["test"] == "value")
            #expect(a["key2"] == "value2")
        }

        @Test func testKeyGetSet() {
            var a: FlatDictionary<String, String> = [:]
            a["key"] = "value"
            #expect(a["key"] == "value")
            a["key"] = nil
            #expect(a["key2"] == nil)
        }

        @Test func testKeyGetFirst() {
            var a: FlatDictionary<String, String> = [:]
            a.append(key: "key", value: "value1")
            a.append(key: "key", value: "value2")
            #expect(a["key"] == "value1")
        }
    }
}
