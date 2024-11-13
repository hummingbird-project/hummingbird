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

import Foundation

/// Structure holding a single cookie
public struct Cookie: Sendable, CustomStringConvertible {
    public enum SameSite: String, Sendable {
        case lax = "Lax"
        case secure = "Secure"
        case none = "None"
    }

    /// Cookie name
    public let name: String
    /// Cookie value
    public let value: String
    /// properties
    public let properties: Properties

    /// indicates the maximum lifetime of the cookie
    public var expires: Date? { return self.properties[.expires].map { DateCache.rfc1123Formatter.date(from: $0) } ?? nil }
    /// indicates the maximum lifetime of the cookie in seconds. Max age has precedence over expires
    /// (not all user agents support max-age)
    public var maxAge: Int? { return self.properties[.maxAge].map { Int($0) } ?? nil }
    /// specifies those hosts to which the cookie will be sent
    public var domain: String? { return self.properties[.domain] }
    /// The scope of each cookie is limited to a set of paths, controlled by the Path attribute
    public var path: String? { return self.properties[.path] }
    /// The Secure attribute limits the scope of the cookie to "secure" channels
    public var secure: Bool { return self.properties[.secure] != nil }
    /// The HttpOnly attribute limits the scope of the cookie to HTTP requests
    public var httpOnly: Bool { return self.properties[.httpOnly] != nil }
    /// The SameSite attribute lets servers specify whether/when cookies are sent with cross-origin requests
    public var sameSite: SameSite? { return self.properties[.sameSite].map { SameSite(rawValue: $0) } ?? nil }

    /// Create `Cookie`
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
        self.name = name
        self.value = value
        var properties = Properties()
        properties[.expires] = expires.map { DateCache.rfc1123Formatter.string(from: $0) }
        properties[.maxAge] = maxAge?.description
        properties[.domain] = domain
        properties[.path] = path
        if secure { properties[.secure] = "" }
        if httpOnly { properties[.httpOnly] = "" }
        self.properties = properties
    }

    /// Create `Cookie`
    /// - Parameters:
    ///   - name: Name of cookie
    ///   - value: Value of cookie
    ///   - expires: indicates the maximum lifetime of the cookie
    ///   - maxAge: indicates the maximum lifetime of the cookie in seconds. Max age has precedence over expires (not all user agents support max-age)
    ///   - domain: specifies those hosts to which the cookie will be sent
    ///   - path: The scope of each cookie is limited to a set of paths, controlled by the Path attribute
    ///   - secure: The Secure attribute limits the scope of the cookie to "secure" channels
    ///   - httpOnly: The HttpOnly attribute limits the scope of the cookie to HTTP requests
    ///   - sameSite: The SameSite attribute lets servers specify whether/when cookies are sent with cross-origin requests
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
        self.name = name
        self.value = value
        var properties = Properties()
        properties[.expires] = expires.map { DateCache.rfc1123Formatter.string(from: $0) }
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
        let elements = header.split(separator: ";")
        guard elements.count > 0 else { return nil }
        let keyValue = elements[0].split(separator: "=", maxSplits: 1)
        guard keyValue.count == 2 else { return nil }
        self.name = String(keyValue[0])
        self.value = String(keyValue[1])

        var properties = Properties()
        // extract elements
        for element in elements.dropFirst() {
            let keyValue = element.split(separator: "=", maxSplits: 1)
            let key = keyValue[0].drop { $0 == " " }
            if keyValue.count == 2 {
                properties[key] = String(keyValue[1])
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
