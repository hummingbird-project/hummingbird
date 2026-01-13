//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

#if compiler(>=6.2)
@_documentation(visibility: internal)
public typealias _HB_SendableMetatype = SendableMetatype
#else
@_documentation(visibility: internal)
public typealias _HB_SendableMetatype = Any
#endif
