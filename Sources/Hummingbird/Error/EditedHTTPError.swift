//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import HTTPTypes
import HummingbirdCore

/// Error generated from another error that adds additional headers to the response
struct EditedHTTPError: HTTPResponseError {
    let originalError: Error
    var status: HTTPResponse.Status {
        (originalError as? HTTPResponseError)?.status ?? .internalServerError
    }
    var headers: HTTPFields {
        var headers = (originalError as? HTTPResponseError)?.headers ?? [:]
        headers.append(contentsOf: additionalHeaders)
        return headers
    }
    let additionalHeaders: HTTPFields

    init(originalError: Error, additionalHeaders: HTTPFields) {
        self.originalError = originalError
        self.additionalHeaders = additionalHeaders
    }

    func response(from request: Request, context: some RequestContext) throws -> Response {
        if let originalError = originalError as? HTTPResponseError {
            var response = try originalError.response(from: request, context: context)
            response.headers.append(contentsOf: additionalHeaders)
            return response
        }

        return Response(status: .internalServerError, headers: additionalHeaders)
    }
}
