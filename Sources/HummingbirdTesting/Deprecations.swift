//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

// Below is a list of unavailable symbols with the "HB" prefix. These are available
// temporarily to ease transition from the old symbols that included the "HB"
// prefix to the new ones.
//
// This file will be removed before we do a 2.0 release

@_documentation(visibility: internal) @available(*, unavailable, renamed: "TestClientProtocol")
public typealias HBXCTClientProtocol = TestClientProtocol
@_documentation(visibility: internal) @available(*, unavailable, renamed: "TestClient")
public typealias HBXCTClient = TestClient
@_documentation(visibility: internal) @available(*, unavailable, renamed: "TestResponse")
public typealias HBXCTResponse = TestResponse
