//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import HTTPAPIs
import HummingbirdCore

// If we catch a too many bytes error report that as payload too large
@available(hummingbird 3.0, *)
extension RequestAsyncReaderError: HTTPResponseError {
    package var status: HTTPTypes.HTTPResponse.Status {
        switch self {
        case .streamEndedBeforeReceivingRequestEnd: .badRequest
        case .tooLarge: .contentTooLarge
        }
    }

    package func writeResponse(
        from request: Request,
        writer: consuming some ResponseWriter & ~Copyable,
        context: some RequestContext
    ) async throws {
        try await writer.sendAndFinish(.init(status: self.status))
    }
}
