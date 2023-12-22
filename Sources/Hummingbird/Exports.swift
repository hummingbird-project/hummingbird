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

@_exported import enum HummingbirdCore.HBBindAddress
@_exported import struct HummingbirdCore.HBHTTPError
@_exported import protocol HummingbirdCore.HBHTTPResponseError
@_exported import enum HummingbirdCore.HBRequestBody
@_exported import enum HummingbirdCore.HBResponseBody
@_exported import protocol HummingbirdCore.HBResponseBodyStreamer
@_exported import enum HummingbirdCore.HBStreamerOutput
@_exported import protocol HummingbirdCore.HBStreamerProtocol
#if canImport(Network)
@_exported import struct HummingbirdCore.TSTLSOptions
#endif

#if swift(>=5.8)
@_exported @_documentation(visibility: internal) import struct NIOCore.ByteBuffer
@_exported @_documentation(visibility: internal) import struct NIOCore.ByteBufferAllocator
@_exported @_documentation(visibility: internal) import protocol NIOCore.EventLoop
@_exported @_documentation(visibility: internal) import class NIOCore.EventLoopFuture
@_exported @_documentation(visibility: internal) import protocol NIOCore.EventLoopGroup
@_exported @_documentation(visibility: internal) import enum NIOCore.SocketAddress
@_exported @_documentation(visibility: internal) import struct NIOCore.TimeAmount

@_exported @_documentation(visibility: internal) import struct NIOHTTP1.HTTPHeaders
@_exported @_documentation(visibility: internal) import enum NIOHTTP1.HTTPMethod
@_exported @_documentation(visibility: internal) import enum NIOHTTP1.HTTPResponseStatus
#else
@_exported import struct NIOCore.ByteBuffer
@_exported import struct NIOCore.ByteBufferAllocator
@_exported import protocol NIOCore.EventLoop
@_exported import class NIOCore.EventLoopFuture
@_exported import protocol NIOCore.EventLoopGroup
@_exported import enum NIOCore.SocketAddress
@_exported import struct NIOCore.TimeAmount

@_exported import struct NIOHTTP1.HTTPHeaders
@_exported import enum NIOHTTP1.HTTPMethod
@_exported import enum NIOHTTP1.HTTPResponseStatus
#endif
