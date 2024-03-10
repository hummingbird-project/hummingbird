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

// Below is a list of deprecated symbols with the "HB" prefix. These are available
// temporarily to ease transition from the old symbols that included the "HB"
// prefix to the new ones.
//
// This file will be removed before we do a 2.0 release

@_documentation(visibility: internal) @available(*, deprecated, renamed: "Request")
public typealias HBRequest = Request
@_documentation(visibility: internal) @available(*, deprecated, renamed: "RequestBody")
public typealias HBRequestBody = RequestBody
@_documentation(visibility: internal) @available(*, deprecated, renamed: "Response")
public typealias HBResponse = Response
@_documentation(visibility: internal) @available(*, deprecated, renamed: "ResponseBody")
public typealias HBResponseBody = ResponseBody
@_documentation(visibility: internal) @available(*, deprecated, renamed: "ResponseBodyWriter")
public typealias HBResponseBodyWriter = ResponseBodyWriter
@_documentation(visibility: internal) @available(*, deprecated, renamed: "HTTPError")
public typealias HBHTTPError = HTTPError
@_documentation(visibility: internal) @available(*, deprecated, renamed: "HTTPResponseError")
public typealias HBHTTPResponseError = HTTPResponseError
@_documentation(visibility: internal) @available(*, deprecated, renamed: "Server")
public typealias HBServer = Server
@_documentation(visibility: internal) @available(*, deprecated, renamed: "ServerConfiguration")
public typealias HBServerConfiguration = ServerConfiguration
@_documentation(visibility: internal) @available(*, deprecated, renamed: "URI")
public typealias HBURL = URI
