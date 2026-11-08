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
    struct PercentEncoding {
        @available(hummingbird 2.0, *)
        @Test(arguments: [
            ("test", "test", URLComponentSet.path),
            ("test=", "test%3D", .queryItem),
            ("test$", "test$", .path),
            ("test[#", "test%5B%23", .query),
            ("test[1]", "test%5B1%5D", .query),
            (":/?#[]", ":/%3F%23%5B%5D", .path),
        ])
        func testPercentEncoding(string: String, encodedString: String, component: URLComponentSet) async throws {
            #expect(string.addingPercentEncoding(forURLComponent: component) == encodedString)
        }

        @available(hummingbird 2.0, *)
        @Test(arguments: [
            ("test", "test"),
            ("test=", "test%3D"),
            ("test$", "test$"),
            ("test[#", "test%5B%23"),
            ("test[1]", "test%5B1%5D"),
            (":/?#[]", ":/%3F%23%5B%5D"),
            (":/?#[]", ":/%3f%23%5b%5d"),
        ])
        func testPercentDecoding(string: String, encodedString: String) async throws {
            #expect(encodedString.removingURLPercentEncoding() == string)
        }

        @available(hummingbird 2.0, *)
        @Test(arguments: [
            "Test%4G",
            "Test%4GThis",
            "Test%Z6This2",
            "Test%A",
            "Test%",
        ])
        func testPercentDecodingFailed(encodedString: String) async throws {
            #expect(encodedString.removingURLPercentEncoding() == nil)
        }
    }
}
