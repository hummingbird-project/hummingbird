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

// Below is a list of unavailable symbols with the "HB" prefix. These are available
// temporarily to ease transition from the old symbols that included the "HB"
// prefix to the new ones.
//
// This file will be removed before we do a 2.0 release

@_documentation(visibility: internal) @available(*, unavailable, renamed: "Request")
public typealias HBRequest = Request
@_documentation(visibility: internal) @available(*, unavailable, renamed: "RequestBody")
public typealias HBRequestBody = RequestBody
@_documentation(visibility: internal) @available(*, unavailable, renamed: "Response")
public typealias HBResponse = Response
@_documentation(visibility: internal) @available(*, unavailable, renamed: "ResponseBody")
public typealias HBResponseBody = ResponseBody
@_documentation(visibility: internal) @available(*, unavailable, renamed: "ResponseBodyWriterProtocol")
public typealias HBResponseBodyWriter = ResponseBodyWriterProtocol
@_documentation(visibility: internal) @available(*, unavailable, renamed: "Server")
public typealias HBServer = Server
@_documentation(visibility: internal) @available(*, unavailable, renamed: "ServerConfiguration")
public typealias HBServerConfiguration = ServerConfiguration
@_documentation(visibility: internal) @available(*, unavailable, renamed: "URI")
public typealias HBURL = URI
