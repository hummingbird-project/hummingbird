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

import HummingbirdCore
import NIOHTTP1

/// Holds all the required to generate a HTTP Response
public struct HBResponse: HBSendableExtensible, HBSendable {
    /// response status
    public var status: HTTPResponseStatus
    /// response headers
    public var headers: HTTPHeaders
    /// response body
    public var body: HBResponseBody
    /// Response extensions
    public var extensions: HBSendableExtensions<HBResponse>

    /// Create an `HBResponse`
    ///
    /// - Parameters:
    ///   - status: response status
    ///   - headers: response headers
    ///   - body: response body
    public init(status: HTTPResponseStatus, headers: HTTPHeaders = [:], body: HBResponseBody = .empty) {
        self.status = status
        self.headers = headers
        self.body = body
        self.extensions = .init()
    }
}

extension HBResponse: CustomStringConvertible {
    public var description: String {
        "status: \(self.status), headers: \(self.headers), body: \(self.body)"
    }
}
