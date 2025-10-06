//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2025 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

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
