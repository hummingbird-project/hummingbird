//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import HTTPTypes
import HummingbirdCore

/// Error generated from another error that adds additional headers to the response
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

    func response(from request: Request, context: some RequestContext) throws -> Response {
        if let originalError = originalError as? (any HTTPResponseError) {
            var response = try originalError.response(from: request, context: context)
            response.headers.append(contentsOf: self.additionalHeaders)
            return response
        }

        return Response(status: .internalServerError, headers: self.additionalHeaders)
    }
}
