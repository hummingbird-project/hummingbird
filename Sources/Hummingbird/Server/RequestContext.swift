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

/// Context that created HBRequest. 
public protocol HBRequestContext {
    /// EventLoop request is running on
    var eventLoop: EventLoop { get }
    /// ByteBuffer allocator used by request
    var allocator: ByteBufferAllocator { get }
    /// Connected host address
    var remoteAddress: SocketAddress? { get }
}
