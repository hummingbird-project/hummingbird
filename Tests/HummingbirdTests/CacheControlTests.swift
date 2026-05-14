//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import Hummingbird
import Testing

extension HTTPTests {
    struct CacheControlTests {
        @Test func testCssIsText() {
            let cacheControl = CacheControl([
                (MediaType(type: .text), [.noCache, .public])
            ])
            #expect(cacheControl.getCacheControlHeader(for: "test.css") == "no-cache, public")
        }

        @Test func testMultipleEntries() {
            let cacheControl = CacheControl([
                (MediaType.textCss, [.noStore]),
                (MediaType.text, [.noCache, .public]),
            ])
            #expect(cacheControl.getCacheControlHeader(for: "test.css") == "no-store")
        }

        @Test func testCssIsAny() {
            let cacheControl = CacheControl([
                (MediaType(type: .any), [.noCache, .public])
            ])
            #expect(cacheControl.getCacheControlHeader(for: "test.css") == "no-cache, public")
        }
    }
}
