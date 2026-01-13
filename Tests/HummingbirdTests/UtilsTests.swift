//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

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
