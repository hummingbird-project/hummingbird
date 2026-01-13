//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

/// Associates cache control values with filename
public struct CacheControl: Sendable {
    /// Cache control directive
    ///
    /// Original CacheControl directive value was a fixed enum. This has been replaced
    /// with CacheControl.CacheControlValue which is more extensible
    @_documentation(visibility: internal)
    public enum Value: CustomStringConvertible, Sendable {
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

        var cacheControlValue: CacheControlValue {
            switch self {
            case .noStore: .noStore
            case .noCache: .noCache
            case .private: .private
            case .public: .public
            case .maxAge(let value): .maxAge(value)
            case .mustRevalidate: .mustRevalidate
            }
        }
    }

    /// Cache control directive
    public struct CacheControlValue: CustomStringConvertible, Sendable {
        private enum Value: CustomStringConvertible, Sendable {
            case noStore
            case noCache
            case `private`
            case `public`
            case maxAge(Int)
            case mustRevalidate
            case mustUnderstand
            case noTransform
            case immutable
            case custom(String)

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
                case .mustUnderstand:
                    return "must-understand"
                case .noTransform:
                    return "no-transform"
                case .immutable:
                    return "immutable"
                case .custom(let string):
                    return string
                }
            }
        }
        private let value: Value

        /// The no-store response directive indicates that any caches of any kind (private or shared) should not
        /// store this response.
        public static var noStore: Self { .init(value: .noStore) }
        /// The no-cache response directive indicates that the response can be stored in caches, but the response
        /// must be validated with the origin server before each reuse, even when the cache is disconnected from
        /// the origin server.
        public static var noCache: Self { .init(value: .noCache) }
        /// The private response directive indicates that the response can be stored only in a private cache (e.g.
        /// local caches in browsers).
        public static var `private`: Self { .init(value: .private) }
        /// The public response directive indicates that the response can be stored in a shared cache. Responses
        /// for requests with Authorization header fields must not be stored in a shared cache; however, the public
        /// directive will cause such responses to be stored in a shared cache.
        public static var `public`: Self { .init(value: .public) }
        /// The max-age=N response directive indicates that the response remains fresh until N seconds after the
        /// response is generated.
        public static func maxAge(_ amount: Int) -> Self { .init(value: .maxAge(amount)) }
        /// The must-revalidate response directive indicates that the response can be stored in caches and can be
        /// reused while fresh. If the response becomes stale, it must be validated with the origin server before reuse.
        public static var mustRevalidate: Self { .init(value: .mustRevalidate) }
        /// The must-understand response directive indicates that a cache should store the response only if it
        /// understands the requirements for caching based on status code.
        public static var mustUnderstand: Self { .init(value: .mustUnderstand) }
        /// Some intermediaries transform content for various reasons. For example, some convert images to reduce
        /// transfer size. In some cases, this is undesirable for the content provider.
        ///
        /// no-transform indicates that any intermediary (regardless of whether it implements a cache) shouldn't transform
        /// the response contents.
        public static var noTransform: Self { .init(value: .noTransform) }
        /// The immutable response directive indicates that the response will not be updated while it's fresh.
        public static var immutable: Self { .init(value: .immutable) }
        /// Custom directive
        public static func custom(_ string: String) -> Self { .init(value: .custom(string)) }

        public var description: String { value.description }
    }

    /// Initialize cache control
    /// - Parameter entries: cache control entries
    @_disfavoredOverload
    public init(_ entries: [(MediaType, [Value])]) {
        self.entries = entries.map {
            .init(
                mediaType: $0.0,
                cacheControl: $0.1.map { $0.cacheControlValue }
            )
        }
    }

    /// Initialize cache control
    /// - Parameter entries: cache control entries
    public init(_ entries: [(MediaType, [CacheControlValue])]) {
        self.entries = entries.map {
            .init(
                mediaType: $0.0,
                cacheControl: $0.1.map { $0 }
            )
        }
    }

    /// Get the Cache-Control header for a file
    /// - Parameter file: file name
    /// - Returns: Cache-control header value
    public func getCacheControlHeader(for file: String) -> String? {
        guard let extPointIndex = file.lastIndex(of: ".") else { return nil }
        let extIndex = file.index(after: extPointIndex)
        let ext = String(file.suffix(from: extIndex))
        guard let mediaType = MediaType.getMediaType(forExtension: ext) else { return nil }
        guard let entry = self.entries.first(where: { mediaType.isType($0.mediaType) }) else { return nil }
        return entry.cacheControl
            .map(\.description)
            .joined(separator: ", ")
    }

    private struct Entry: Sendable {
        let mediaType: MediaType
        let cacheControl: [CacheControlValue]
    }

    private let entries: [Entry]
}
