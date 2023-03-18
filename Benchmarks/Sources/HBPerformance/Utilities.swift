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

import NIOCore

public func randomBuffer(size: Int) -> ByteBuffer {
    var data = [UInt8](repeating: 0, count: size)
    data = data.map { _ in UInt8.random(in: 0...255) }
    return ByteBufferAllocator().buffer(bytes: data)
}
