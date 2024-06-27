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

@_exported import struct HummingbirdCore.BindAddress
@_exported import struct HummingbirdCore.Request
@_exported import struct HummingbirdCore.RequestBody
@_exported import struct HummingbirdCore.Response
@_exported import struct HummingbirdCore.ResponseBody
@_exported import protocol HummingbirdCore.ResponseBodyWriter
#if canImport(Network)
@_exported import struct HummingbirdCore.TSTLSOptions
#endif

@_exported @_documentation(visibility: internal) import struct NIOCore.ByteBuffer
@_exported @_documentation(visibility: internal) import struct NIOCore.ByteBufferAllocator

@_exported @_documentation(visibility: internal) import struct HTTPTypes.HTTPFields
@_exported @_documentation(visibility: internal) import struct HTTPTypes.HTTPRequest
@_exported @_documentation(visibility: internal) import struct HTTPTypes.HTTPResponse

// Temporary exports of unavailable typealiases
@_exported import struct HummingbirdCore.HBRequest
@_exported import struct HummingbirdCore.HBRequestBody
@_exported import struct HummingbirdCore.HBResponse
@_exported import struct HummingbirdCore.HBResponseBody
@_exported import protocol HummingbirdCore.HBResponseBodyWriter
