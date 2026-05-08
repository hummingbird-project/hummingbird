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
///     .reportTo: "csp-endpoint"
/// ]
/// ```
public struct ContentSecurityPolicy: Sendable, CustomStringConvertible, ExpressibleByArrayLiteral {
    /// Content-security-policy directive
    public struct Directive: Sendable, CustomStringConvertible {
        @usableFromInline
        enum Internal: Sendable {
            case fetch(FetchDirective, [FetchDirectiveValue])
            case baseURI([URIRestrictionValue])
            case sandbox(SandboxValue?)
            case formAction([URIRestrictionValue])
            case frameAncestors([URIRestrictionValue])
            case reportTo(String)
            case requireTrustedTypesFor([RequireTrustedTypesForValue])
            case trustedTypes([TrustedTypesValue])
            case upgradeInsecureRequests
            case blockAllMixedContent
            case reportUri(String)
        }

        @usableFromInline
        enum FetchDirective: String, Sendable {
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
        }

        @usableFromInline
        let value: Internal

        @usableFromInline
        init(value: Internal) {
            self.value = value
        }

        @inlinable public var description: String {
            switch self.value {
            case .fetch(let directive, let values): "\(directive.rawValue) \(values.lazy.map { $0.description }.joined(separator: " "))"
            case .baseURI(let values): "base-uri \(values.lazy.map { $0.description }.joined(separator: " "))"
            case .sandbox(let value): "sandbox\(value.map { " \($0.description)"} ?? "")"
            case .formAction(let values): "form-action \(values.lazy.map { $0.description }.joined(separator: " "))"
            case .frameAncestors(let values): "frame-ancestors \(values.lazy.map { $0.description }.joined(separator: " "))"
            case .reportTo(let endpoint): "report-to \(endpoint)"
            case .requireTrustedTypesFor(let values): "require-trusted-types-for \(values.lazy.map { $0.description }.joined(separator: " "))"
            case .trustedTypes(let values): "trusted-types \(values.lazy.map { $0.description }.joined(separator: " "))"
            case .upgradeInsecureRequests: "upgrade-insecure-requests"
            case .blockAllMixedContent: "block-all-mixed-content"
            case .reportUri(let endpoint): "report-uri \(endpoint)"
            }
        }

        /// Fetch directives
        ///
        /// Fetch directives control the locations from which certain resource types may be loaded.

        /// Defines the valid sources for web workers and nested browsing contexts loaded using elements such as
        /// \<frame\> and \<iframe\>.
        @inlinable public static func childSrc(_ values: FetchDirectiveValue...) -> Self { .init(value: .fetch(.childSrc, values)) }
        /// Restricts the URLs which can be loaded using script interfaces.
        @inlinable public static func connectSrc(_ values: FetchDirectiveValue...) -> Self { .init(value: .fetch(.connectSrc, values)) }
        /// Serves as a fallback for the other fetch directives.
        @inlinable public static func defaultSrc(_ values: FetchDirectiveValue...) -> Self { .init(value: .fetch(.defaultSrc, values)) }
        /// Specifies valid sources for nested browsing contexts loaded into \<fencedframe\> elements.
        @inlinable public static func fencedFrameSrc(_ values: FetchDirectiveValue...) -> Self { .init(value: .fetch(.fencedFrameSrc, values)) }
        /// Specifies valid sources for fonts loaded using @font-face.
        @inlinable public static func fontSrc(_ values: FetchDirectiveValue...) -> Self { .init(value: .fetch(.fontSrc, values)) }
        /// Specifies valid sources for nested browsing contexts loaded into elements such as \<frame\> and \<iframe\>.
        @inlinable public static func frameSrc(_ values: FetchDirectiveValue...) -> Self { .init(value: .fetch(.frameSrc, values)) }
        /// Specifies valid sources of images and favicons.
        @inlinable public static func imgSrc(_ values: FetchDirectiveValue...) -> Self { .init(value: .fetch(.imgSrc, values)) }
        /// Specifies valid sources of application manifest files.
        @inlinable public static func manifestSrc(_ values: FetchDirectiveValue...) -> Self { .init(value: .fetch(.manifestSrc, values)) }
        /// Specifies valid sources for loading media using the \<audio\>, \<video\> and \<track\> elements.
        @inlinable public static func mediaSrc(_ values: FetchDirectiveValue...) -> Self { .init(value: .fetch(.mediaSrc, values)) }
        /// Specifies valid sources for the \<object\> and \<embed\> elements.
        @inlinable public static func objectSrc(_ values: FetchDirectiveValue...) -> Self { .init(value: .fetch(.objectSrc, values)) }
        /// Specifies valid sources to be prefetched or prerendered.
        @inlinable public static func prefetchSrc(_ values: FetchDirectiveValue...) -> Self { .init(value: .fetch(.prefetchSrc, values)) }
        /// Specifies valid sources for JavaScript and WebAssembly resources.
        @inlinable public static func scriptSrc(_ values: FetchDirectiveValue...) -> Self { .init(value: .fetch(.scriptSrc, values)) }
        /// Specifies valid sources for JavaScript \<script\> elements.
        @inlinable public static func scriptSrcElem(_ values: FetchDirectiveValue...) -> Self { .init(value: .fetch(.scriptSrcElem, values)) }
        /// Specifies valid sources for JavaScript inline event handlers.
        @inlinable public static func scriptSrcAttr(_ values: FetchDirectiveValue...) -> Self { .init(value: .fetch(.scriptSrcAttr, values)) }
        /// Specifies valid sources for stylesheets.
        @inlinable public static func styleSrc(_ values: FetchDirectiveValue...) -> Self { .init(value: .fetch(.styleSrc, values)) }
        /// Specifies valid sources for stylesheets \<style\> elements and \<link\> elements with rel="stylesheet".
        @inlinable public static func styleSrcElem(_ values: FetchDirectiveValue...) -> Self { .init(value: .fetch(.styleSrcElem, values)) }
        /// Specifies valid sources for inline styles applied to individual DOM elements.
        @inlinable public static func styleSrcAttr(_ values: FetchDirectiveValue...) -> Self { .init(value: .fetch(.styleSrcAttr, values)) }
        /// Specifies valid sources for Worker, SharedWorker, or ServiceWorker scripts.
        @inlinable public static func workerSrc(_ values: FetchDirectiveValue...) -> Self { .init(value: .fetch(.workerSrc, values)) }

        /// Document directives
        ///
        /// Document directives govern the properties of a document or worker environment to which a policy applies.

        /// Restricts the URLs which can be used in a document's \<base\> element.
        @inlinable public static func baseURI(_ values: URIRestrictionValue...) -> Self { .init(value: .baseURI(values)) }
        /// Enables a sandbox for the requested resource similar to the \<iframe\> sandbox attribute.
        @inlinable public static func sandbox(_ value: SandboxValue?) -> Self { .init(value: .sandbox(value)) }

        /// Navigation directives
        ///
        /// Navigation directives govern to which locations a user can navigate or submit a form, for example.

        /// Restricts the URLs which can be used as the target of a form submissions from a given context.
        @inlinable public static func formAction(_ values: URIRestrictionValue...) -> Self { .init(value: .formAction(values)) }
        /// Specifies valid parents that may embed a page using \<frame\>, \<iframe\>, \<object\>, or \<embed\>.
        @inlinable public static func frameAncestors(_ values: URIRestrictionValue...) -> Self { .init(value: .frameAncestors(values)) }

        /// Reporting directives
        ///
        /// Reporting directives control the destination URL for CSP violation reports in Content-Security-Policy and Content-Security-Policy-Report-Only.

        /// Provides the browser with a token identifying the reporting endpoint or group of endpoints to send CSP violation information to. The endpoints
        /// that the token represents are provided through other HTTP headers, such as Reporting-Endpoints and Report-To.
        @inlinable public static func reportTo(_ endpoint: String) -> Self { .init(value: .reportTo(endpoint)) }

        /// Other directives

        /// Enforces Trusted Types at the DOM XSS injection sinks.
        @inlinable public static func requireTrustedTypesFor(_ values: RequireTrustedTypesForValue...) -> Self {
            .init(value: .requireTrustedTypesFor(values))
        }
        /// Used to specify an allowlist of Trusted Types policies. Trusted Types allows applications to lock down DOM XSS injection sinks to only
        /// accept non-spoofable, typed values in place of strings.
        @inlinable public static func trustedTypes(_ values: TrustedTypesValue...) -> Self { .init(value: .trustedTypes(values)) }
        /// Instructs user agents to treat all of a site's insecure URLs (those served over HTTP) as though they have been replaced with secure URLs (those
        /// served over HTTPS). This directive is intended for websites with large numbers of insecure legacy URLs that need to be rewritten.
        @inlinable public static var upgradeInsecureRequests: Self { .init(value: .upgradeInsecureRequests) }

        /// Deprecated directives

        /// (deprecated) Prevents loading any assets using HTTP when the page is loaded using HTTPS.
        @inlinable public static var blockAllMixedContent: Self { .init(value: .blockAllMixedContent) }
        /// (deprecated) Provides the browser with a URL where CSP violation reports should be sent. This has been superseded by the report-to directive.
        @inlinable public static func reportUri(_ endpoint: String) -> Self { .init(value: .reportUri(endpoint)) }
    }

    /// Content-security-policy value scheme
    public struct Scheme: Sendable {
        public let rawValue: String

        @inlinable
        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        @inlinable public static var http: Self { .init(rawValue: "http:") }
        @inlinable public static var https: Self { .init(rawValue: "https:") }
        @inlinable public static var ws: Self { .init(rawValue: "ws:") }
        @inlinable public static var wss: Self { .init(rawValue: "wss:") }
    }

    /// Content-security-policy value hash
    public struct HashAlgorithm: Sendable {
        public let rawValue: String

        @inlinable
        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        @inlinable public static var sha256: Self { .init(rawValue: "sha256") }
        @inlinable public static var sha384: Self { .init(rawValue: "sha384") }
        @inlinable public static var sha512: Self { .init(rawValue: "sha512") }
    }

    /// Content-security-policy fetch directive value
    ///
    /// These are to be used with fetch directives.
    /// ```
    /// let csp: ContentSecurityPolicy = [
    ///     .defaultSrc(.self),
    ///     .imgSrc("/images")
    /// ]
    /// ```
    public struct FetchDirectiveValue: Sendable, CustomStringConvertible, ExpressibleByStringLiteral {
        @usableFromInline
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

        @usableFromInline
        let value: Internal

        @usableFromInline
        init(value: Internal) {
            self.value = value
        }

        /// The single value 'none', indicating that the specific resource type should be completely blocked
        @inlinable public static var none: Self { .init(.none) }
        /// Resources of the given type may only be loaded from the same origin as the document.
        @inlinable public static var `self`: Self { .init(.self) }
        /// This value consists of the string nonce- followed by a nonce value. The nonce value may use any of the
        /// characters from Base64 or URL-safe Base64.
        @inlinable public static func nonce(_ base64: String) -> Self { .init(.nonce(base64)) }
        /// This value consists of a string identifying a hash algorithm, followed by -, followed by a hash value.
        /// The hash value may use any of the characters from Base64 or URL-safe Base64.
        @inlinable public static func hash(_ algorithm: HashAlgorithm, base64: String) -> Self { .init(.hash(algorithm, base64)) }
        /// The URL or IP address of a host that is a valid source for the resource.
        /// The scheme, port number, and path are optional.
        /// If the scheme is omitted, the scheme of the document's origin is used.
        @inlinable public static func uri(_ uri: String) -> Self { .init(.raw(uri)) }
        /// A scheme, such as https:
        @inlinable public static func scheme(_ scheme: Scheme) -> Self { .init(.raw(scheme.rawValue)) }
        /// By default, if a CSP contains a default-src or a script-src directive, then JavaScript functions which
        /// evaluate their arguments as JavaScript are disabled. This includes eval(), the code argument to setTimeout(),
        /// or the Function() constructor.
        ///
        /// The trusted-types-eval keyword can be used to undo this protection, but only when Trusted Types are enforced
        /// and passed to these functions instead of strings. This allows dynamic evaluation of strings as JavaScript,
        /// but only after inputs have been passed through a transformation function before it is injected, which has
        /// the chance to sanitize the input to remove potentially dangerous markup.
        @inlinable public static var trustedTypesEval: Self { .init(.trustedTypesEval) }
        /// By default, if a CSP contains a default-src or a script-src directive, then JavaScript functions which
        /// evaluate their arguments as JavaScript are disabled. This includes eval(), the code argument to setTimeout(),
        /// or the Function() constructor.
        ///
        /// The unsafe-eval keyword can be used to undo this protection, allowing dynamic evaluation of strings as
        /// JavaScript.
        /// > Developers should avoid using `unsafe-eval`
        @inlinable public static var unsafeEval: Self { .init(.unsafeEval) }
        /// By default, if a CSP contains a default-src or a script-src directive, then a page won't be allowed to
        /// compile WebAssembly using functions like WebAssembly.compileStreaming().
        ///
        /// The wasm-unsafe-eval keyword can be used to undo this protection. This is a much safer alternative to
        /// 'unsafe-eval', since it does not enable general evaluation of JavaScript.
        @inlinable public static var wasmUnsafeEval: Self { .init(.wasmUnsafeEval) }
        /// By default, if a CSP contains a default-src or a script-src directive, then inline JavaScript is not
        /// allowed to execute.
        ///
        /// The unsafe-inline keyword can be used to undo this protection, allowing all these forms to be loaded.
        /// > Developers should avoid using `unsafe-inline`
        @inlinable public static var unsafeInline: Self { .init(.unsafeInline) }
        /// By default, if a CSP contains a default-src or a script-src directive, then inline event handler attributes
        /// like onclick and inline style attributes are not allowed to execute.
        ///
        /// The 'unsafe-hashes' expression allows the browser to use hash expressions for inline event handlers
        /// and style attributes.
        @inlinable public static var unsafeHashes: Self { .init(.unsafeHashes) }
        /// By default, if a CSP contains a default-src or a script-src directive, then inline JavaScript is not
        /// allowed to execute. The 'inline-speculation-rules' allows the browser to load inline \<script\> elements
        /// that have a type attribute of speculationrules.
        @inlinable public static var inlineSpeculationRules: Self { .init(.inlineSpeculationRules) }
        /// The 'strict-dynamic' keyword makes the trust conferred on a script by a nonce or a hash extend to scripts
        /// that this script dynamically loads, for example by creating new \<script\> tags using Document.createElement()
        /// and then inserting them into the document using Node.appendChild().
        @inlinable public static var strictDynamic: Self { .init(.strictDynamic) }
        /// If this expression is included in a directive controlling scripts or styles, and the directive causes the
        /// browser to block any inline scripts, inline styles, or event handler attributes, then the violation report
        /// that the browser generates will contain a sample property containing the first 40 characters of the blocked
        /// resource.
        @inlinable public static var reportSample: Self { .init(.reportSample) }

        @inlinable public var description: String {
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

        @usableFromInline
        init(_ value: Internal) {
            self.value = value
        }

        @inlinable
        public init(stringLiteral value: String) {
            self.value = .raw(value)
        }
    }

    public struct URIRestrictionValue: Sendable, CustomStringConvertible, ExpressibleByStringLiteral {
        @usableFromInline
        enum Internal: Sendable {
            case none
            case `self`
            case raw(String)
        }

        @usableFromInline
        let value: Internal

        @usableFromInline
        init(_ value: Internal) {
            self.value = value
        }

        @inlinable public var description: String {
            switch self.value {
            case .none: "'none'"
            case .self: "'self'"
            case .raw(let string): string
            }
        }

        /// The single value 'none', indicating that the specific resource type should be completely blocked
        @inlinable public static var none: Self { .init(.none) }
        /// Resources of the given type may only be loaded from the same origin as the document.
        @inlinable public static var `self`: Self { .init(.self) }
        /// The URL or IP address of a host that is a valid source for the resource.
        /// The scheme, port number, and path are optional.
        /// If the scheme is omitted, the scheme of the document's origin is used.
        @inlinable public static func uri(_ uri: String) -> Self { .init(.raw(uri)) }
        /// A scheme, such as https:
        @inlinable public static func scheme(_ scheme: Scheme) -> Self { .init(.raw(scheme.rawValue)) }

        @inlinable
        public init(stringLiteral value: String) {
            self.value = .raw(value)
        }
    }

    public struct SandboxValue: Sendable, CustomStringConvertible {
        @usableFromInline
        enum Internal: String, Sendable {
            case allowDownloads = "allow-downloads"
            case allowForms = "allow-forms"
            case allowModals = "allow-modals"
            case allowOrientationLock = "allow-orientation-lock"
            case allowPointerLock = "allow-pointer-lock"
            case allowPopups = "allow-popups"
            case allowPopupsToEscapeSandbox = "allow-popups-to-escape-sandbox"
            case allowPresentation = "allow-presentation"
            case allowSameOrigin = "allow-same-origin"
            case allowScripts = "allow-scripts"
            case allowStorageAccessByUserActivation = "allow-storage-access-by-user-activation"
            case allowTopNavigation = "allow-top-navigation"
            case allowTopNavigationByUserNavigation = "allow-top-navigation-by-user-activation"
            case allowTopNavigationToCustomProtocols = "allow-top-navigation-to-custom-protocols"
        }

        @usableFromInline
        let value: Internal

        @usableFromInline
        init(_ value: Internal) {
            self.value = value
        }

        @inlinable public var description: String {
            self.value.rawValue
        }

        @inlinable public static var allowDownloads: Self { .init(.allowDownloads) }
        @inlinable public static var allowForms: Self { .init(.allowForms) }
        @inlinable public static var allowModals: Self { .init(.allowModals) }
        @inlinable public static var allowOrientationLock: Self { .init(.allowOrientationLock) }
        @inlinable public static var allowPointerLock: Self { .init(.allowPointerLock) }
        @inlinable public static var allowPopups: Self { .init(.allowPopups) }
        @inlinable public static var allowPopupsToEscapeSandbox: Self { .init(.allowPopupsToEscapeSandbox) }
        @inlinable public static var allowPresentation: Self { .init(.allowPresentation) }
        @inlinable public static var allowSameOrigin: Self { .init(.allowSameOrigin) }
        @inlinable public static var allowScripts: Self { .init(.allowScripts) }
        @inlinable public static var allowStorageAccessByUserActivation: Self { .init(.allowStorageAccessByUserActivation) }
        @inlinable public static var allowTopNavigation: Self { .init(.allowTopNavigation) }
        @inlinable public static var allowTopNavigationByUserNavigation: Self { .init(.allowTopNavigationByUserNavigation) }
        @inlinable public static var allowTopNavigationToCustomProtocols: Self { .init(.allowTopNavigationToCustomProtocols) }
    }

    /// Possible values for `trusted-types` directive
    public struct TrustedTypesValue: Sendable, CustomStringConvertible {
        @usableFromInline
        enum Internal: Sendable {
            case none
            case allowDuplicates
            case policyName(String)
        }

        @usableFromInline
        let value: Internal

        @usableFromInline
        init(_ value: Internal) {
            self.value = value
        }

        @inlinable public var description: String {
            switch self.value {
            case .none: "'none'"
            case .allowDuplicates: "'allow-duplicates'"
            case .policyName(let string): string
            }
        }

        /// Disallows creating any Trusted Type policy (same as not specifying any <policyName>).
        @inlinable public static var none: Self { .init(.none) }
        /// Allows for creating policies with a name that was already used.
        @inlinable public static var allowDuplicates: Self { .init(.allowDuplicates) }
        /// Allows for creating policies with a name that was already used.
        @inlinable public static func policyName(_ name: String) -> Self { .init(.policyName(name)) }
    }

    /// Possible values for `require-trusted-types-for` directive. Currently this can only by `.script`
    public struct RequireTrustedTypesForValue: Sendable, CustomStringConvertible {
        @usableFromInline
        enum Internal: String, Sendable {
            case script = "'script'"
        }

        @usableFromInline
        let value: Internal

        @usableFromInline
        init(_ value: Internal) {
            self.value = value
        }

        @inlinable public var description: String {
            self.value.rawValue
        }

        @inlinable public static var script: Self { .init(.script) }
    }

    @usableFromInline
    let policyDirectives: [Directive]

    ///  Initialize Content Security Policy from an array of directive and directive value array pairs
    /// - Parameter policyDirectives: Array of directive and directive value array pairs
    @inlinable
    public init(_ policyDirectives: [Directive]) {
        self.policyDirectives = policyDirectives
    }

    ///  Initialize Content Security Policy from a array literal of directives
    /// - Parameter policyDirectives: Array of directives
    @inlinable
    public init(arrayLiteral elements: Directive...) {
        self.policyDirectives = elements
    }

    /// Formatted output for content-security-policy header
    @inlinable public var description: String {
        self.policyDirectives.lazy.map { "\($0)" }.joined(separator: "; ")
    }
}
