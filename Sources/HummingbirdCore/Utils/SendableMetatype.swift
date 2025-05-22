//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2025 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if compiler(>=6.2)
@_documentation(visibility: internal)
public typealias _HB_SendableMetatype = SendableMetatype
@_documentation(visibility: internal)
public typealias _HB_SendableMetatypeAsyncIteratorProtocol = AsyncIteratorProtocol & SendableMetatype
#else
@_documentation(visibility: internal)
public protocol _HB_SendableMetatype {}
@_documentation(visibility: internal)
public typealias _HB_SendableMetatypeAsyncIteratorProtocol = AsyncIteratorProtocol
#endif
