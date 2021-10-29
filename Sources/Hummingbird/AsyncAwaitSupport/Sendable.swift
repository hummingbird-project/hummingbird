//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Logging
import NIOHTTP1

#if swift(>=5.5) && canImport(_Concurrency)

// imported symbols that need Sendable conformance
// from Logging
extension Logger: @unchecked HBSendable {}
extension Logger.Level: @unchecked HBSendable {}
// from NIOCore
// from NIOHTTP1
extension HTTPVersion: @unchecked HBSendable {}
extension HTTPMethod: @unchecked HBSendable {}
extension HTTPHeaders: @unchecked HBSendable {}
extension HTTPResponseStatus: @unchecked Sendable {}

#endif
