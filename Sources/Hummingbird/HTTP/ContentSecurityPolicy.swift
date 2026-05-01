//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

public struct ContentSecurityPolicy: Sendable, CustomStringConvertible {
    public struct FetchDirective: Sendable {
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

        /// Fetch directives
        ///
        /// Fetch directives control the locations from which certain resource types may be loaded.

        /// Defines the valid sources for web workers and nested browsing contexts loaded using elements such as <frame> and <iframe>.
        public static var childSrc: Self { .init(value: .childSrc) }
        /// Restricts the URLs which can be loaded using script interfaces.
        public static var connectSrc: Self { .init(value: .connectSrc) }
        /// Serves as a fallback for the other fetch directives.
        public static var defaultSrc: Self { .init(value: .defaultSrc) }
        /// Specifies valid sources for nested browsing contexts loaded into <fencedframe> elements.
        public static var fencedFrameSrc: Self { .init(value: .fencedFrameSrc) }
        /// Specifies valid sources for fonts loaded using @font-face.
        public static var fontSrc: Self { .init(value: .fontSrc) }
        /// Specifies valid sources for nested browsing contexts loaded into elements such as <frame> and <iframe>.
        public static var frameSrc: Self { .init(value: .frameSrc) }
        /// Specifies valid sources of images and favicons.
        public static var imgSrc: Self { .init(value: .imgSrc) }
        /// Specifies valid sources of application manifest files.
        public static var manifestSrc: Self { .init(value: .manifestSrc) }
        /// Specifies valid sources for loading media using the <audio>, <video> and <track> elements.
        public static var mediaSrc: Self { .init(value: .mediaSrc) }
        /// Specifies valid sources for the <object> and <embed> elements.
        public static var objectSrc: Self { .init(value: .objectSrc) }
        /// Specifies valid sources to be prefetched or prerendered.
        public static var prefetchSrc: Self { .init(value: .prefetchSrc) }
        /// Specifies valid sources for JavaScript and WebAssembly resources.
        public static var scriptSrc: Self { .init(value: .scriptSrc) }
        /// Specifies valid sources for JavaScript <script> elements.
        public static var scriptSrcElem: Self { .init(value: .scriptSrcElem) }
        /// Specifies valid sources for JavaScript inline event handlers.
        public static var scriptSrcAttr: Self { .init(value: .scriptSrcAttr) }
        /// Specifies valid sources for stylesheets.
        public static var styleSrc: Self { .init(value: .styleSrc) }
        /// Specifies valid sources for stylesheets <style> elements and <link> elements with rel="stylesheet".
        public static var styleSrcElem: Self { .init(value: .styleSrcElem) }
        /// Specifies valid sources for inline styles applied to individual DOM elements.
        public static var styleSrcAttr: Self { .init(value: .styleSrcAttr) }
        /// Specifies valid sources for Worker, SharedWorker, or ServiceWorker scripts.
        public static var workerSrc: Self { .init(value: .workerSrc) }

        /// Document directives
        ///
        /// Document directives govern the properties of a document or worker environment to which a policy applies.

        /// Restricts the URLs which can be used in a document's <base> element.
        public static var baseUri: Self { .init(value: .baseUri) }
        /// Enables a sandbox for the requested resource similar to the <iframe> sandbox attribute.
        public static var sandbox: Self { .init(value: .sandbox) }

        /// Navigation directives
        ///
        /// Navigation directives govern to which locations a user can navigate or submit a form, for example.

        /// Restricts the URLs which can be used as the target of a form submissions from a given context.
        public static var formAction: Self { .init(value: .formAction) }
        /// Specifies valid parents that may embed a page using <frame>, <iframe>, <object>, or <embed>.
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

    public struct FetchDirectiveValue: Sendable, CustomStringConvertible {
        enum Internal {
            case none
            case `self`
            case nonce(base64: String)
            case sha256(base64: String)
            case sha384(base64: String)
            case sha512(base64: String)
            case hostSource(String)
            case http
            case https
            case ws
            case wss
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

        public var description: String {
            switch self.value {
            case .none: "'none'"
            case .self: "'self'"
            case .nonce(let string): "'nonce-\(string)'"
            case .sha256(let string): "'sha256-\(string)'"
            case .sha384(let string): "'sha384-\(string)'"
            case .sha512(let string): "'sha512-\(string)'"
            case .hostSource(let string): string
            case .http: "http:"
            case .https: "https:"
            case .ws: "ws:"
            case .wss: "wss."
            case .trustedTypesEval: "trusted-types-eval"
            case .unsafeEval: "unsafe-eval"
            case .wasmUnsafeEval: "wasm-unsafe-eval"
            case .unsafeInline: "unsafe-inline"
            case .unsafeHashes: "unsafe-hashes"
            case .inlineSpeculationRules: "inline-speculation-rules"
            case .strictDynamic: "strict-dynamic"
            case .reportSample: "report-sample"
            }
        }
    }
    public struct PolicyDirective: Sendable {
        let value: String

        public init(_ fetchDirective: FetchDirective, values: [FetchDirectiveValue]) {
            self.value = "\(fetchDirective) \(values)"
        }
    }
    let policyDirectives: [PolicyDirective]

    public var description: String { self.policyDirectives.map { $0.value }.joined(separator: "; ") }
}
