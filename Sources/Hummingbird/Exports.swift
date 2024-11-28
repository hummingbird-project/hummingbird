//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@_exported @_documentation(visibility: internal) import struct HTTPTypes.HTTPFields
@_exported @_documentation(visibility: internal) import struct HTTPTypes.HTTPRequest
@_exported @_documentation(visibility: internal) import struct HTTPTypes.HTTPResponse
@_exported @_documentation(visibility: internal) import struct HummingbirdCore.BindAddress
// Temporary exports of unavailable typealiases
@_exported @_documentation(visibility: internal) import struct HummingbirdCore.HBRequest
@_exported @_documentation(visibility: internal) import struct HummingbirdCore.HBRequestBody
@_exported @_documentation(visibility: internal) import struct HummingbirdCore.HBResponse
@_exported @_documentation(visibility: internal) import struct HummingbirdCore.HBResponseBody
@_exported @_documentation(visibility: internal) import protocol HummingbirdCore.HBResponseBodyWriter
@_exported @_documentation(visibility: internal) import struct HummingbirdCore.Request
@_exported @_documentation(visibility: internal) import struct HummingbirdCore.RequestBody
@_exported @_documentation(visibility: internal) import struct HummingbirdCore.Response
@_exported @_documentation(visibility: internal) import struct HummingbirdCore.ResponseBody
@_exported @_documentation(visibility: internal) import protocol HummingbirdCore.ResponseBodyWriter
@_exported @_documentation(visibility: internal) import struct NIOCore.ByteBuffer
@_exported @_documentation(visibility: internal) import struct NIOCore.ByteBufferAllocator

#if canImport(Network)
@_exported @_documentation(visibility: internal) import struct HummingbirdCore.TSTLSOptions
#endif
