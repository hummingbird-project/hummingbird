//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import HTTPAPIs
public import HTTPTypes
public import HummingbirdCore
public import NIOCore

// If we catch a too many bytes error report that as payload too large
@available(hummingbird 3.0, *)
extension NIOTooManyBytesError: HTTPResponseError {
    public var status: HTTPResponse.Status { .contentTooLarge }
    public var headers: HTTPFields { [:] }

    public func writeResponse(
        from request: Request,
        writer: consuming some ResponseWriter & ~Copyable,
        context: some RequestContext
    ) async throws {
        try await writer.sendAndFinish(.init(status: self.status))
    }
}
