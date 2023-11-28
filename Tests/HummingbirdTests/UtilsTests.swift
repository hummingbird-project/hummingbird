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
import XCTest

class FlatDictionaryTests: XCTestCase {
    func testLiteralInit() {
        let a: FlatDictionary<String, String> = ["test": "value", "key2": "value2"]
        XCTAssertEqual(a["test"], "value")
        XCTAssertEqual(a["key2"], "value2")
    }

    func testKeyGetSet() {
        var a: FlatDictionary<String, String> = [:]
        a["key"] = "value"
        XCTAssertEqual(a["key"], "value")
        a["key"] = nil
        XCTAssertEqual(a["key2"], nil)
    }

    func testKeyGetFirst() {
        var a: FlatDictionary<String, String> = [:]
        a.append(key: "key", value: "value1")
        a.append(key: "key", value: "value2")
        XCTAssertEqual(a["key"], "value1")
    }
}
