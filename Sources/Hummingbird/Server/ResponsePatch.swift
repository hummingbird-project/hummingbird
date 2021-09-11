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

import NIOHTTP1

extension HBRequest {
    // MARK: Response patching

    /// Patches Response via `HBResponse.apply(patch:)`
    ///
    /// Allow you to patch the response generated by your route handler via the `HBRequest` supplied. If your handler is only
    /// returning the payload you can edit the status and headers via `request.response` eg.
    /// ```
    /// func myHandler(_ request: HBRequest) -> String {
    ///     request.response.status = .accepted
    ///     return "hello"
    /// }
    /// ```
    public class ResponsePatch {
        /// patch status of reponse
        public var status: HTTPResponseStatus?
        /// headers to add to response
        public var headers: HTTPHeadersPatch

        init() {
            self.status = nil
            self.headers = [:]
        }
    }

    /// Allows you to edit the status and headers of the response
    public var response: ResponsePatch {
        get { self.extensions.get(\.response) }
        set { self.extensions.set(\.response, value: newValue) }
    }

    /// return `ResponsePatch` only if it exists. Used internally
    var optionalResponse: ResponsePatch? {
        self.extensions.get(\.response)
    }
}

extension HBResponse {
    /// apply `HBRequest.ResponsePatch` to `HBResponse`
    func apply(patch: HBRequest.ResponsePatch?) -> Self {
        guard let patch = patch else { return self }
        if let status = patch.status {
            self.status = status
        }
        self.headers.apply(patch: patch.headers)
        return self
    }
}

/// Used to Patch HTTPHeaders. Remembers if a header was added in with `add` or `replaceOrAdd`
public struct HTTPHeadersPatch: ExpressibleByDictionaryLiteral {
    @usableFromInline
    internal var addHeaders: HTTPHeaders
    internal var replaceHeaders: HTTPHeaders

    /// Construct a `HTTPHeaders` structure.
    ///
    /// - parameters
    ///     - elements: name, value pairs provided by a dictionary literal.
    public init(dictionaryLiteral elements: (String, String)...) {
        self.replaceHeaders = .init(elements)
        self.addHeaders = .init()
    }

    /// Add a header name/value pair to the block.
    ///
    /// This method is strictly additive: if there are other values for the given header name
    /// already in the block, this will add a new entry.
    ///
    /// - Parameter name: The header field name. For maximum compatibility this should be an
    ///     ASCII string. For future-proofing with HTTP/2 lowercase header names are strongly
    ///     recommended.
    /// - Parameter value: The header field value to add for the given name.
    public mutating func add(name: String, value: String) {
        self.addHeaders.add(name: name, value: value)
    }

    /// Add a sequence of header name/value pairs to the block.
    ///
    /// This method is strictly additive: if there are other entries with the same header
    /// name already in the block, this will add new entries.
    ///
    /// - Parameter contentsOf: The sequence of header name/value pairs. For maximum compatibility
    ///     the header should be an ASCII string. For future-proofing with HTTP/2 lowercase header
    ///     names are strongly recommended.
    @inlinable
    public mutating func add<S: Sequence>(contentsOf other: S) where S.Element == (String, String) {
        self.addHeaders.add(contentsOf: other)
    }

    /// Add a header name/value pair to the block, replacing any previous values for the
    /// same header name that are already in the block.
    ///
    /// This is a supplemental method to `add` that essentially combines `remove` and `add`
    /// in a single function. It can be used to ensure that a header block is in a
    /// well-defined form without having to check whether the value was previously there.
    /// Like `add`, this method performs case-insensitive comparisons of the header field
    /// names.
    ///
    /// - Parameter name: The header field name. For maximum compatibility this should be an
    ///     ASCII string. For future-proofing with HTTP/2 lowercase header names are strongly
    //      recommended.
    /// - Parameter value: The header field value to add for the given name.
    public mutating func replaceOrAdd(name: String, value: String) {
        self.addHeaders.remove(name: name)
        self.replaceHeaders.remove(name: name)
        self.replaceHeaders.add(name: name, value: value)
    }

    /// Remove all values for a given header name from the block.
    ///
    /// This method uses case-insensitive comparisons for the header field name.
    ///
    /// - Parameter name: The name of the header field to remove from the block.
    public mutating func remove(name nameToRemove: String) {
        self.addHeaders.remove(name: nameToRemove)
        self.replaceHeaders.remove(name: nameToRemove)
    }
}

extension HTTPHeaders {
    /// Apply header patch to headers
    /// - Parameter patch: header patch
    mutating func apply(patch: HTTPHeadersPatch) {
        self.add(contentsOf: patch.addHeaders)
        for header in patch.replaceHeaders {
            self.replaceOrAdd(name: header.name, value: header.value)
        }
    }
}
