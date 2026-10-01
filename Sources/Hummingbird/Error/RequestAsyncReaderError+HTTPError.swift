//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import HummingbirdCore

// If we catch a too many bytes error report that as payload too large
extension RequestAsyncReaderError: HTTPResponseError {
    package var status: HTTPTypes.HTTPResponse.Status {
        switch self {
        case .streamEndedBeforeReceivingRequestEnd: .badRequest
        case .tooLarge: .contentTooLarge
        }
    }

    public func response(from request: Request, context: some RequestContext) throws -> Response {
        Response(status: self.status)
    }
}
