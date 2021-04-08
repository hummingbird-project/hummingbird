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

import Hummingbird

/// Structure holding an array of cookies
///
/// Cookies can be accessed from request via `HBRequest.cookies`.
public struct HBCookies {
    public typealias CollectionType = [String: HBCookie]

    /// Construct array of cookies from `HBRequest`
    /// - Parameter request: request to get cookies from
    init(from request: HBRequest) {
        self.map = .init(request.headers["cookie"].flatMap {
            return $0.split(separator: ";")
                .compactMap {
                    guard let cookie = HBCookie(from: String($0.drop { $0.isWhitespace })) else { return nil }
                    return (cookie.name, cookie)
                }
        }) { first, _ in first }
    }

    /// access cookies via dictionary subscript
    public subscript(_ key: String) -> HBCookie? {
        get { return self.map[key] }
        set { self.map[key] = newValue }
    }

    var map: CollectionType
}

/// extend `HBCookies` to conform to `Collection`
extension HBCookies: Collection {
    public typealias Element = CollectionType.Element

    public func index(after i: CollectionType.Index) -> CollectionType.Index {
        return self.map.index(after: i)
    }

    public subscript(_ index: CollectionType.Index) -> HBCookies.Element {
        return self.map[index]
    }

    public var startIndex: CollectionType.Index { self.map.startIndex }
    public var endIndex: CollectionType.Index { self.map.endIndex }
}
