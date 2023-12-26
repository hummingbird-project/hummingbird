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

@_exported import enum HummingbirdCore.HBBindAddress
@_exported import struct HummingbirdCore.HBHTTPError
@_exported import protocol HummingbirdCore.HBHTTPResponseError
@_exported import struct HummingbirdCore.HBRequest
@_exported import enum HummingbirdCore.HBRequestBody
@_exported import struct HummingbirdCore.HBResponse
@_exported import struct HummingbirdCore.HBResponseBody
@_exported import protocol HummingbirdCore.HBResponseBodyWriter
#if canImport(Network)
@_exported import struct HummingbirdCore.TSTLSOptions
#endif

@_exported @_documentation(visibility: internal) import struct NIOCore.ByteBuffer
@_exported @_documentation(visibility: internal) import struct NIOCore.ByteBufferAllocator

@_exported @_documentation(visibility: internal) import struct HTTPTypes.HTTPFields
@_exported @_documentation(visibility: internal) import struct HTTPTypes.HTTPRequest
@_exported @_documentation(visibility: internal) import struct HTTPTypes.HTTPResponse
