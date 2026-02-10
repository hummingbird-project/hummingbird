//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

#if canImport(FoundationEssentials)
public import FoundationEssentials
#else
public import Foundation
#endif

/// Structure holding a single cookie
@available(macOS 13, iOS 16, tvOS 16, *)
public struct Cookie: Sendable, CustomStringConvertible {
    public struct ValidationError: Error {
        enum Reason {
            case invalidName
            case invalidValue
        }

        let reason: Reason
    }

    public enum SameSite: String, Sendable {
        case lax = "Lax"
        case strict = "Strict"
        case none = "None"

        @available(*, deprecated, renamed: "strict", message: "Secure is not a valid value for SameSite, use strict instead")
        static var secure: Self { .strict }
    }

    /// Cookie name
    public let name: String
    /// Cookie value
    public let value: String
    /// properties
    public let properties: Properties

    /// indicates the maximum lifetime of the cookie
    public var expires: Date? { self.properties[.expires].flatMap { Date(httpHeader: $0) } }
    /// indicates the maximum lifetime of the cookie in seconds. Max age has precedence over expires
    /// (not all user agents support max-age)
    public var maxAge: Int? { self.properties[.maxAge].map { Int($0) } ?? nil }
    /// specifies those hosts to which the cookie will be sent
    public var domain: String? { self.properties[.domain] }
    /// The scope of each cookie is limited to a set of paths, controlled by the Path attribute
    public var path: String? { self.properties[.path] }
    /// The Secure attribute limits the scope of the cookie to "secure" channels
    public var secure: Bool { self.properties[.secure] != nil }
    /// The HttpOnly attribute limits the scope of the cookie to HTTP requests
    public var httpOnly: Bool { self.properties[.httpOnly] != nil }
    /// The SameSite attribute lets servers specify whether/when cookies are sent with cross-origin requests
    public var sameSite: SameSite? { self.properties[.sameSite].map { SameSite(rawValue: $0) } ?? nil }

    private static func isValidValue(_ value: String) -> Bool {
        // RFC 6265 Section 4.1.1: cookie-octet set
        // Allowed: 0x21, 0x23-0x2B, 0x2D-0x3A, 0x3C-0x5B, 0x5D-0x7E
        value.utf8.allSatisfy { byte in
            (byte == 0x21) || (0x23...0x2B).contains(byte) || (0x2D...0x3A).contains(byte) || (0x3C...0x5B).contains(byte)
                || (0x5D...0x7E).contains(byte)
        }
    }

    private static func isValidName(_ name: String) -> Bool {
        // RFC 2616 Section 2.2: token = 1*<any CHAR except CTLs or separators>
        // CTLs: 0-31, 127
        // Separators: ()<>@,;:\"/[]?={} \t
        let separators: Set<UInt8> = [
            UInt8(ascii: "("),
            UInt8(ascii: ")"),
            UInt8(ascii: "<"),
            UInt8(ascii: ">"),
            UInt8(ascii: "@"),
            UInt8(ascii: ","),
            UInt8(ascii: ";"),
            UInt8(ascii: ":"),
            UInt8(ascii: "\\"),
            UInt8(ascii: "\""),
            UInt8(ascii: "/"),
            UInt8(ascii: "["),
            UInt8(ascii: "]"),
            UInt8(ascii: "?"),
            UInt8(ascii: "="),
            UInt8(ascii: "{"),
            UInt8(ascii: "}"),
        ]
        // Space is no in the separators, but is added to the CTLs because it's right behind the last CTL
        // `0x1F` is the last CTL, and space is `0x20`
        return !name.isEmpty
            && name.utf8.allSatisfy { byte in
                (byte >= 0x21 && byte != 127 && !separators.contains(byte))
            }
    }

    /// Create `Cookie` and validates the name and value to be valid as per RFC 6265.
    ///
    /// If the name and value are not valid, an `ValidationError` will be thrown. Contrary to
    /// the equivalent initializer, this function will not `assert` on DEBUG for invalid names
    /// and values.
    ///
    /// - Parameters:
    ///   - name: Name of cookie
    ///   - value: Value of cookie
    ///   - expires: indicates the maximum lifetime of the cookie
    ///   - maxAge: indicates the maximum lifetime of the cookie in seconds. Max age has precedence
    ///         over expires (not all user agents support max-age)
    ///   - domain: specifies those hosts to which the cookie will be sent
    ///   - path: The scope of each cookie is limited to a set of paths, controlled by the Path attribute
    ///   - secure: The Secure attribute limits the scope of the cookie to "secure" channels
    ///   - httpOnly: The HttpOnly attribute limits the scope of the cookie to HTTP requests
    ///   - sameSite: The SameSite attribute lets servers specify whether/when cookies are sent with cross-origin requests
    public static func validated(
        name: String,
        value: String,
        expires: Date? = nil,
        maxAge: Int? = nil,
        domain: String? = nil,
        path: String? = nil,
        secure: Bool = false,
        httpOnly: Bool = true,
        sameSite: SameSite? = nil
    ) throws -> Cookie {
        guard Cookie.isValidName(name) else {
            throw ValidationError(reason: .invalidName)
        }

        guard Cookie.isValidValue(value) else {
            throw ValidationError(reason: .invalidValue)
        }

        assert(!(secure == false && sameSite == Cookie.SameSite.none), "Cookies with SameSite set to None require the Secure attribute to be set")

        if let sameSite {
            return Cookie(
                name: name,
                value: value,
                expires: expires,
                maxAge: maxAge,
                domain: domain,
                path: path,
                secure: secure,
                httpOnly: httpOnly,
                sameSite: sameSite
            )
        } else {
            return Cookie(
                name: name,
                value: value,
                expires: expires,
                maxAge: maxAge,
                domain: domain,
                path: path,
                secure: secure,
                httpOnly: httpOnly
            )
        }
    }

    /// Create `Cookie`. The `name` and `value` are assumed to contain valid characters as per RFC 6265.
    ///
    /// If the name and value are not valid, an `assert` will fail on DEBUG, or the cookie will be have
    /// an invalid `String` representation on RELEASE.
    ///
    /// Use ``Cookie/validated(name:value:expires:maxAge:domain:path:secure:httpOnly:sameSite:)`` to create
    /// a cookie while validating name and value.
    ///
    /// - Parameters:
    ///   - name: Name of cookie
    ///   - value: Value of cookie
    ///   - expires: indicates the maximum lifetime of the cookie
    ///   - maxAge: indicates the maximum lifetime of the cookie in seconds. Max age has precedence over expires (not all user agents support max-age)
    ///   - domain: specifies those hosts to which the cookie will be sent
    ///   - path: The scope of each cookie is limited to a set of paths, controlled by the Path attribute
    ///   - secure: The Secure attribute limits the scope of the cookie to "secure" channels
    ///   - httpOnly: The HttpOnly attribute limits the scope of the cookie to HTTP requests
    public init(
        name: String,
        value: String,
        expires: Date? = nil,
        maxAge: Int? = nil,
        domain: String? = nil,
        path: String? = nil,
        secure: Bool = false,
        httpOnly: Bool = true
    ) {
        assert(Cookie.isValidName(name), "Cookie name contains invalid characters as per RFC 6265")
        assert(Cookie.isValidValue(value), "Cookie value contains invalid characters as per RFC 6265")

        self.name = name
        self.value = value
        var properties = Properties()
        properties[.expires] = expires?.httpHeader
        properties[.maxAge] = maxAge?.description
        properties[.domain] = domain
        properties[.path] = path
        if secure { properties[.secure] = "" }
        if httpOnly { properties[.httpOnly] = "" }
        self.properties = properties
    }

    /// Create `Cookie`. The `name` and `value` are assumed to contain valid characters as per RFC 6265.
    ///
    /// If the name and value are not valid, an `assert` will fail on DEBUG, or the cookie will be have
    /// an invalid `String` representation on RELEASE.
    ///
    /// Use ``Cookie/validated(name:value:expires:maxAge:domain:path:secure:httpOnly:sameSite:)`` to create
    /// a cookie while validating name and value.
    ///
    /// - Parameters:
    ///   - name: Name of cookie
    ///   - value: Value of cookie
    ///   - expires: indicates the maximum lifetime of the cookie
    ///   - maxAge: indicates the maximum lifetime of the cookie in seconds. Max age has precedence over
    ///         expires (not all user agents support max-age)
    ///   - domain: specifies those hosts to which the cookie will be sent
    ///   - path: The scope of each cookie is limited to a set of paths, controlled by the Path attribute
    ///   - secure: The Secure attribute limits the scope of the cookie to "secure" channels
    ///   - httpOnly: The HttpOnly attribute limits the scope of the cookie to HTTP requests
    ///   - sameSite: The SameSite attribute lets servers specify whether/when cookies are sent with
    ///         cross-origin requests
    public init(
        name: String,
        value: String,
        expires: Date? = nil,
        maxAge: Int? = nil,
        domain: String? = nil,
        path: String? = nil,
        secure: Bool = false,
        httpOnly: Bool = true,
        sameSite: SameSite
    ) {
        assert(Cookie.isValidName(name), "Cookie name contains invalid characters as per RFC 6265")
        assert(!(secure == false && sameSite == .none), "Cookies with SameSite set to None require the Secure attribute to be set")
        assert(Cookie.isValidValue(value), "Cookie value contains invalid characters as per RFC 6265")

        self.name = name
        self.value = value
        var properties = Properties()
        properties[.expires] = expires?.httpHeader
        properties[.maxAge] = maxAge?.description
        properties[.domain] = domain
        properties[.path] = path
        if secure { properties[.secure] = "" }
        if httpOnly { properties[.httpOnly] = "" }
        properties[.sameSite] = sameSite.rawValue
        self.properties = properties
    }

    /// Construct cookie from cookie header value
    /// - Parameter header: cookie header value
    internal init?(from header: Substring) {
        var iterator = header.splitSequence(separator: ";").makeIterator()
        guard let keyValue = iterator.next() else { return nil }
        var keyValueIterator = keyValue.splitMaxSplitsSequence(separator: "=", maxSplits: 1).makeIterator()
        guard let key = keyValueIterator.next() else { return nil }
        guard let value = keyValueIterator.next() else { return nil }
        self.name = String(key)
        self.value = String(value)

        var properties = Properties()
        // extract elements
        while let element = iterator.next() {
            var keyValueIterator = element.splitMaxSplitsSequence(separator: "=", maxSplits: 1).makeIterator()
            guard var key = keyValueIterator.next() else { return nil }
            key = key.drop(while: \.isWhitespace)
            if let value = keyValueIterator.next() {
                properties[key] = String(value)
            } else {
                properties[key] = ""
            }
        }
        self.properties = properties
    }

    internal static func getName<S: StringProtocol>(from header: S) -> S.SubSequence? {
        guard let equals = header.firstIndex(of: "=") else { return nil }
        return header[..<equals]
    }

    /// Output cookie string
    public var description: String {
        var output = "\(self.name)=\(self.value)"
        for property in self.properties.table {
            if property.value == "" {
                output += "; \(property.key)"
            } else {
                output += "; \(property.key)=\(property.value)"
            }
        }
        return output
    }

    /// Cookie properties table
    public struct Properties: Sendable {
        /// Common properties of a cookie
        enum CommonProperties: Substring {
            case expires = "Expires"
            case maxAge = "Max-Age"
            case domain = "Domain"
            case path = "Path"
            case secure = "Secure"
            case httpOnly = "HttpOnly"
            case sameSite = "SameSite"
        }

        init() {
            self.table = [:]
        }

        subscript(_ string: String) -> String? {
            get { self.table[string[...]] }
            set { self.table[string[...]] = newValue }
        }

        public subscript(_ string: Substring) -> String? {
            get { self.table[string] }
            set { self.table[string] = newValue }
        }

        subscript(_ property: CommonProperties) -> String? {
            get { self.table[property.rawValue] }
            set { self.table[property.rawValue] = newValue }
        }

        var table: [Substring: String]
    }
}
