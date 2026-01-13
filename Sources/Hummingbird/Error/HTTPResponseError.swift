//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

public import HTTPTypes

/// An error that is capable of generating an HTTP response
///
/// By conforming to `HTTPResponseError` you can control how your error will be presented to
/// the client. Errors not conforming to this will be returned with status internalServerError.
public protocol HTTPResponseError: Error, ResponseGenerator {
    /// status code for the error
    var status: HTTPResponse.Status { get }
}
