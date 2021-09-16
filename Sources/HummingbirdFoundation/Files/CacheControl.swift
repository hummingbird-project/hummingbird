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

/// Associates cache control values with filename
public struct HBCacheControl {
    public enum Value: CustomStringConvertible {
        case noStore
        case noCache
        case `private`
        case `public`
        case maxAge(Int)
        case mustRevalidate

        public var description: String {
            switch self {
            case .noStore:
                return "no-store"
            case .noCache:
                return "no-cache"
            case .private:
                return "private"
            case .public:
                return "public"
            case .maxAge(let amount):
                return "max-age=\(amount)"
            case .mustRevalidate:
                return "must-revalidate"
            }
        }
    }

    /// Initialize cache control
    /// - Parameter entries: cache control entries
    public init(_ entries: [(HBMediaType, [Value])]) {
        self.entries = entries.map { .init(mediaType: $0.0, cacheControl: $0.1) }
    }

    /// Get the Cache-Control header for a file
    /// - Parameter file: file name
    /// - Returns: Cache-control header value
    public func getCacheControlHeader(for file: String) -> String? {
        guard let extPointIndex = file.lastIndex(of: ".") else { return nil }
        let extIndex = file.index(after: extPointIndex)
        let ext = String(file.suffix(from: extIndex))
        guard let mediaType = HBMediaType.getMediaType(forExtension: ext) else { return nil }
        guard let entry = self.entries.first(where: { mediaType.isType($0.mediaType) }) else { return nil }
        return entry.cacheControl
            .map(\.description)
            .joined(separator: ", ")
    }

    private struct Entry {
        let mediaType: HBMediaType
        let cacheControl: [Value]
    }

    private let entries: [Entry]
}
