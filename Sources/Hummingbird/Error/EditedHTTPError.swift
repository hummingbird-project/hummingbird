//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import HTTPAPIs
import HTTPTypes
import HummingbirdCore

/// Error generated from another error that adds additional headers to the response
@available(hummingbird 3.0, *)
struct EditedHTTPError: HTTPResponseError {
    let originalError: any Error
    var status: HTTPResponse.Status {
        (self.originalError as? (any HTTPResponseError))?.status ?? .internalServerError
    }

    let additionalHeaders: HTTPFields

    init(originalError: any Error, additionalHeaders: HTTPFields) {
        self.originalError = originalError
        self.additionalHeaders = additionalHeaders
    }

    func writeResponse(from request: Request, writer: consuming some ResponseWriter & ~Copyable, context: some RequestContext) async throws {
        if let originalError = originalError as? (any HTTPResponseError) {
            return try await originalError.writeResponse(
                from: request,
                writer: writer.editHead { $0.headerFields.append(contentsOf: self.additionalHeaders) },
                context: context
            )
        }
        try await writer.sendAndFinish(.init(status: .internalServerError, headerFields: self.additionalHeaders))
    }
}
