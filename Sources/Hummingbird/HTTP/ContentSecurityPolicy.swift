//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

/// Helper to build content-security-policy header
///
/// ```
/// let csp: ContentSecurityPolicy = [
///     .scriptSrc: [.hash(.sha256, base64: hash), .strictDynamic],
///     .fontSrc: [.scheme(.https)],
///     .reportTo, "csp-endpoint"
/// ]
/// ```
public struct ContentSecurityPolicy: Sendable, CustomStringConvertible, ExpressibleByDictionaryLiteral {
    /// Content-security-policy directive
    public struct Directive: Sendable, Hashable, CustomStringConvertible {
        enum Internal: String, Hashable {
            case childSrc = "child-src"
            case connectSrc = "connect-src"
            case defaultSrc = "default-src"
            case fencedFrameSrc = "fenced-frame-src"
            case fontSrc = "font-src"
            case frameSrc = "frame-src"
            case imgSrc = "img-src"
            case manifestSrc = "manifest-src"
            case mediaSrc = "media-src"
            case objectSrc = "object-src"
            case prefetchSrc = "prefetch-src"
            case scriptSrc = "script-src"
            case scriptSrcElem = "script-src-elem"
            case scriptSrcAttr = "script-src-attr"
            case styleSrc = "style-src"
            case styleSrcElem = "style-src-elem"
            case styleSrcAttr = "style-src-attr"
            case workerSrc = "worker-src"
            case baseUri = "base-uri"
            case sandbox = "sandbox"
            case formAction = "form-action"
            case formAncestors = "form-ancestors"
            case reportTo = "report-to"
            case requireTrustedTypesFor = "require-trusted-types-for"
            case trustedTypes = "trusted-types"
            case upgradeInsecureRequests = "upgrade-insecure-requests"
            case blockAllMixedContent = "block-mixed-content"
            case reportUri = "report-uri"
        }

        let value: Internal

        public var description: String { self.value.rawValue }

        /// Fetch directives
        ///
        /// Fetch directives control the locations from which certain resource types may be loaded.

        /// Defines the valid sources for web workers and nested browsing contexts loaded using elements such as
        /// \<frame\> and \<iframe\>.
        public static var childSrc: Self { .init(value: .childSrc) }
        /// Restricts the URLs which can be loaded using script interfaces.
        public static var connectSrc: Self { .init(value: .connectSrc) }
        /// Serves as a fallback for the other fetch directives.
        public static var defaultSrc: Self { .init(value: .defaultSrc) }
        /// Specifies valid sources for nested browsing contexts loaded into \<fencedframe\> elements.
        public static var fencedFrameSrc: Self { .init(value: .fencedFrameSrc) }
        /// Specifies valid sources for fonts loaded using @font-face.
        public static var fontSrc: Self { .init(value: .fontSrc) }
        /// Specifies valid sources for nested browsing contexts loaded into elements such as \<frame\> and \<iframe\>.
        public static var frameSrc: Self { .init(value: .frameSrc) }
        /// Specifies valid sources of images and favicons.
        public static var imgSrc: Self { .init(value: .imgSrc) }
        /// Specifies valid sources of application manifest files.
        public static var manifestSrc: Self { .init(value: .manifestSrc) }
        /// Specifies valid sources for loading media using the \<audio\>, \<video\> and \<track\> elements.
        public static var mediaSrc: Self { .init(value: .mediaSrc) }
        /// Specifies valid sources for the \<object\> and \<embed\> elements.
        public static var objectSrc: Self { .init(value: .objectSrc) }
        /// Specifies valid sources to be prefetched or prerendered.
        public static var prefetchSrc: Self { .init(value: .prefetchSrc) }
        /// Specifies valid sources for JavaScript and WebAssembly resources.
        public static var scriptSrc: Self { .init(value: .scriptSrc) }
        /// Specifies valid sources for JavaScript \<script\> elements.
        public static var scriptSrcElem: Self { .init(value: .scriptSrcElem) }
        /// Specifies valid sources for JavaScript inline event handlers.
        public static var scriptSrcAttr: Self { .init(value: .scriptSrcAttr) }
        /// Specifies valid sources for stylesheets.
        public static var styleSrc: Self { .init(value: .styleSrc) }
        /// Specifies valid sources for stylesheets \<style\> elements and \<link\> elements with rel="stylesheet".
        public static var styleSrcElem: Self { .init(value: .styleSrcElem) }
        /// Specifies valid sources for inline styles applied to individual DOM elements.
        public static var styleSrcAttr: Self { .init(value: .styleSrcAttr) }
        /// Specifies valid sources for Worker, SharedWorker, or ServiceWorker scripts.
        public static var workerSrc: Self { .init(value: .workerSrc) }

        /// Document directives
        ///
        /// Document directives govern the properties of a document or worker environment to which a policy applies.

        /// Restricts the URLs which can be used in a document's \<base\> element.
        public static var baseUri: Self { .init(value: .baseUri) }
        /// Enables a sandbox for the requested resource similar to the \<iframe\> sandbox attribute.
        public static var sandbox: Self { .init(value: .sandbox) }

        /// Navigation directives
        ///
        /// Navigation directives govern to which locations a user can navigate or submit a form, for example.

        /// Restricts the URLs which can be used as the target of a form submissions from a given context.
        public static var formAction: Self { .init(value: .formAction) }
        /// Specifies valid parents that may embed a page using \<frame\>, \<iframe\>, \<object\>, or \<embed\>.
        public static var formAncestors: Self { .init(value: .formAncestors) }

        /// Reporting directives
        ///
        /// Reporting directives control the destination URL for CSP violation reports in Content-Security-Policy and Content-Security-Policy-Report-Only.

        /// Provides the browser with a token identifying the reporting endpoint or group of endpoints to send CSP violation information to. The endpoints
        /// that the token represents are provided through other HTTP headers, such as Reporting-Endpoints and Report-To.
        public static var reportTo: Self { .init(value: .reportTo) }

        /// Other directives

        /// Enforces Trusted Types at the DOM XSS injection sinks.
        public static var requireTrustedTypesFor: Self { .init(value: .requireTrustedTypesFor) }
        /// Used to specify an allowlist of Trusted Types policies. Trusted Types allows applications to lock down DOM XSS injection sinks to only
        /// accept non-spoofable, typed values in place of strings.
        public static var trustedTypes: Self { .init(value: .trustedTypes) }
        /// Instructs user agents to treat all of a site's insecure URLs (those served over HTTP) as though they have been replaced with secure URLs (those
        /// served over HTTPS). This directive is intended for websites with large numbers of insecure legacy URLs that need to be rewritten.
        public static var upgradeInsecureRequests: Self { .init(value: .upgradeInsecureRequests) }

        /// Deprecated directives

        /// (deprecated) Prevents loading any assets using HTTP when the page is loaded using HTTPS.
        public static var blockAllMixedContent: Self { .init(value: .blockAllMixedContent) }
        /// (deprecated) Provides the browser with a URL where CSP violation reports should be sent. This has been superseded by the report-to directive.
        public static var reportUri: Self { .init(value: .reportUri) }
    }

    /// Content-security-policy value scheme
    public struct Scheme: Sendable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public static var http: Self { .init(rawValue: "http:") }
        public static var https: Self { .init(rawValue: "https:") }
        public static var ws: Self { .init(rawValue: "ws:") }
        public static var wss: Self { .init(rawValue: "wss:") }
    }

    /// Content-security-policy value hash
    public struct HashAlgorithm: Sendable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public static var sha256: Self { .init(rawValue: "sha256") }
        public static var sha384: Self { .init(rawValue: "sha384") }
        public static var sha512: Self { .init(rawValue: "sha512") }
    }

    /// Content-security-policy directive value
    ///
    /// These are to be used with fetch directives. All other directives expect a raw string eg
    /// ```
    /// let csp: ContentSecurityPolicy = [
    ///     .defaultSrc: [.self],
    ///     .reportTo: "csp-reports"
    /// ]
    /// ```
    public struct DirectiveValue: Sendable, CustomStringConvertible, ExpressibleByStringLiteral {
        enum Internal: Sendable {
            case none
            case `self`
            case nonce(String)
            case hash(HashAlgorithm, String)
            case raw(String)
            case trustedTypesEval
            case unsafeEval
            case wasmUnsafeEval
            case unsafeInline
            case unsafeHashes
            case inlineSpeculationRules
            case strictDynamic
            case reportSample
        }
        let value: Internal

        /// The single value 'none', indicating that the specific resource type should be completely blocked
        public static var none: Self { .init(.none) }
        /// Resources of the given type may only be loaded from the same origin as the document.
        public static var `self`: Self { .init(.self) }
        /// This value consists of the string nonce- followed by a nonce value. The nonce value may use any of the
        /// characters from Base64 or URL-safe Base64.
        public static func nonce(_ base64: String) -> Self { .init(.nonce(base64)) }
        /// This value consists of a string identifying a hash algorithm, followed by -, followed by a hash value.
        /// The hash value may use any of the characters from Base64 or URL-safe Base64.
        public static func hash(_ algorithm: HashAlgorithm, base64: String) -> Self { .init(.hash(algorithm, base64)) }
        /// The URL or IP address of a host that is a valid source for the resource.
        /// The scheme, port number, and path are optional.
        /// If the scheme is omitted, the scheme of the document's origin is used.
        public static func uri(_ uri: String) -> Self { .init(.raw(uri)) }
        /// A scheme, such as https:
        public static func scheme(_ scheme: Scheme) -> Self { .init(.raw(scheme.rawValue)) }
        /// By default, if a CSP contains a default-src or a script-src directive, then JavaScript functions which
        /// evaluate their arguments as JavaScript are disabled. This includes eval(), the code argument to setTimeout(),
        /// or the Function() constructor.
        ///
        /// The trusted-types-eval keyword can be used to undo this protection, but only when Trusted Types are enforced
        /// and passed to these functions instead of strings. This allows dynamic evaluation of strings as JavaScript,
        /// but only after inputs have been passed through a transformation function before it is injected, which has
        /// the chance to sanitize the input to remove potentially dangerous markup.
        public static var trustedTypesEval: Self { .init(.trustedTypesEval) }
        /// By default, if a CSP contains a default-src or a script-src directive, then JavaScript functions which
        /// evaluate their arguments as JavaScript are disabled. This includes eval(), the code argument to setTimeout(),
        /// or the Function() constructor.
        ///
        /// The unsafe-eval keyword can be used to undo this protection, allowing dynamic evaluation of strings as
        /// JavaScript.
        /// > Developers should avoid using `unsafe-eval`
        public static var unsafeEval: Self { .init(.unsafeEval) }
        /// By default, if a CSP contains a default-src or a script-src directive, then a page won't be allowed to
        /// compile WebAssembly using functions like WebAssembly.compileStreaming().
        ///
        /// The wasm-unsafe-eval keyword can be used to undo this protection. This is a much safer alternative to
        /// 'unsafe-eval', since it does not enable general evaluation of JavaScript.
        public static var wasmUnsafeEval: Self { .init(.wasmUnsafeEval) }
        /// By default, if a CSP contains a default-src or a script-src directive, then inline JavaScript is not
        /// allowed to execute.
        ///
        /// The unsafe-inline keyword can be used to undo this protection, allowing all these forms to be loaded.
        /// > Developers should avoid using `unsafe-inline`
        public static var unsafeInline: Self { .init(.unsafeInline) }
        /// By default, if a CSP contains a default-src or a script-src directive, then inline event handler attributes
        /// like onclick and inline style attributes are not allowed to execute.
        ///
        /// The 'unsafe-hashes' expression allows the browser to use hash expressions for inline event handlers
        /// and style attributes.
        public static var unsafeHashes: Self { .init(.unsafeHashes) }
        /// By default, if a CSP contains a default-src or a script-src directive, then inline JavaScript is not
        /// allowed to execute. The 'inline-speculation-rules' allows the browser to load inline \<script\> elements
        /// that have a type attribute of speculationrules.
        public static var inlineSpeculationRules: Self { .init(.inlineSpeculationRules) }
        /// The 'strict-dynamic' keyword makes the trust conferred on a script by a nonce or a hash extend to scripts
        /// that this script dynamically loads, for example by creating new \<script\> tags using Document.createElement()
        /// and then inserting them into the document using Node.appendChild().
        public static var strictDynamic: Self { .init(.strictDynamic) }
        /// If this expression is included in a directive controlling scripts or styles, and the directive causes the
        /// browser to block any inline scripts, inline styles, or event handler attributes, then the violation report
        /// that the browser generates will contain a sample property containing the first 40 characters of the blocked
        /// resource.
        public static var reportSample: Self { .init(.reportSample) }

        public var description: String {
            switch self.value {
            case .none: "'none'"
            case .self: "'self'"
            case .nonce(let string): "'nonce-\(string)'"
            case .hash(let algorithm, let string): "'\(algorithm.rawValue)-\(string)'"
            case .trustedTypesEval: "'trusted-types-eval'"
            case .unsafeEval: "'unsafe-eval'"
            case .wasmUnsafeEval: "'wasm-unsafe-eval'"
            case .unsafeInline: "'unsafe-inline'"
            case .unsafeHashes: "'unsafe-hashes'"
            case .inlineSpeculationRules: "'inline-speculation-rules'"
            case .strictDynamic: "'strict-dynamic'"
            case .reportSample: "'report-sample'"
            case .raw(let string): string
            }
        }

        init(_ value: Internal) {
            self.value = value
        }
        public init(stringLiteral value: String) {
            self.value = .raw(value)
        }
    }

    /// Collection of DirectiveValues
    ///
    /// Can be initialized with either a array literal of `DirectiveValue`, or a String literal.
    public struct DirectiveValues: Sendable, CustomStringConvertible, ExpressibleByStringLiteral, ExpressibleByArrayLiteral {
        public init(_ elements: DirectiveValue...) {
            self.values = elements
        }

        public init(arrayLiteral elements: DirectiveValue...) {
            self.values = elements
        }

        public init(stringLiteral value: String) {
            self.values = [.init(.raw(value))]
        }

        let values: [DirectiveValue]

        public var description: String {
            self.values.lazy.map { $0.description }.joined(separator: " ")
        }
    }
    let policyDirectives: [(Directive, DirectiveValues)]

    ///  Initialize Content Security Policy from an array of directive and directive value array pairs
    /// - Parameter policyDirectives: Array of directive and directive value array pairs
    public init(_ policyDirectives: [(Directive, DirectiveValues)]) {
        self.policyDirectives = policyDirectives
    }

    ///  Initialize Content Security Policy from a dictionary of directive and directive value array pairs
    /// - Parameter policyDirectives: Dictionary of directive and directive value array pairs
    public init(_ policyDirectives: [Directive: DirectiveValues]) {
        self.policyDirectives = policyDirectives.map { $0 }
    }

    ///  Initialize Content Security Policy from a dictionary literal of directive and directive value array pairs
    /// - Parameter policyDirectives: Array of directive and directive value array pairs
    public init(dictionaryLiteral elements: (Directive, DirectiveValues)...) {
        self.policyDirectives = elements
    }

    /// Formatted output for content-security-policy header
    public var description: String {
        self.policyDirectives.lazy.map { "\($0.0) \($0.1)" }.joined(separator: "; ")
    }
}
