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

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Structure holding a single cookie
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
    /// indicate if a cookie has been validated
    public var valid: Bool {
        Cookie.isValidName(self.name) && Cookie.isValidValue(self.value)
    }

    private static func isValidValue(_ value: String) -> Bool {
        // RFC 6265 Section 4.1.1: cookie-octet set
        // Allowed: 0x21, 0x23-0x2B, 0x2D-0x3A, 0x3C-0x5B, 0x5D-0x7E
        return value.utf8.allSatisfy { byte in
            (byte == 0x21) ||
            (0x23...0x2B).contains(byte) ||
            (0x2D...0x3A).contains(byte) ||
            (0x3C...0x5B).contains(byte) ||
            (0x5D...0x7E).contains(byte)
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
        return !name.isEmpty && name.utf8.allSatisfy { byte in
            (byte >= 0x21 && byte != 127 && !separators.contains(byte))
        }
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
    ///   - validate: Check the cookie's name and value for valid characters (throw on failure)
    public init(
        name: String,
        value: String,
        expires: Date? = nil,
        maxAge: Int? = nil,
        domain: String? = nil,
        path: String? = nil,
        secure: Bool = false,
        httpOnly: Bool = true,
        validate: Bool
    ) throws {
        if validate {
            guard Cookie.isValidName(name) else {
                throw ValidationError(reason: .invalidName)
            }

            guard Cookie.isValidValue(value) else {
                throw ValidationError(reason: .invalidValue)
            }
        }
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
    ///   - validate: Check the cookie's name and value for valid characters (throw on failure)
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
        validate: Bool,
        sameSite: SameSite
    ) throws {
        if validate {
            guard Cookie.isValidName(name) else {
                throw ValidationError(reason: .invalidName)
            }

            guard Cookie.isValidValue(value) else {
                throw ValidationError(reason: .invalidValue)
            }
        }

        assert(!(secure == false && sameSite == .none), "Cookies with SameSite set to None require the Secure attribute to be set")
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
    @available(*, deprecated, message: "Use try init(name:value:expires:maxAge:domain:path:secure:httpOnly:validate) (specify validate) instead")
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
        properties[.expires] = expires?.httpHeader
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
    @available(*, deprecated, message: "Use try init(name:value:expires:maxAge:domain:path:secure:httpOnly:validate:sameSite) (specify validate) instead")
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
        assert(!(secure == false && sameSite == .none), "Cookies with SameSite set to None require the Secure attribute to be set")

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
    /// - Parameter validate: check cookie name and value validity
    internal init?(from header: Substring, validate: Bool = true) throws {
        let elements = header.split(separator: ";")
        guard elements.count > 0 else { return nil }
        let keyValue = elements[0].split(separator: "=", maxSplits: 1)
        guard keyValue.count == 2 else { return nil }
        self.name = String(keyValue[0])
        self.value = String(keyValue[1])

        if validate {
            guard Cookie.isValidName(name) else {
                throw ValidationError(reason: .invalidName)
            }
            guard Cookie.isValidValue(value) else {
                throw ValidationError(reason: .invalidValue)
            }
        }

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
