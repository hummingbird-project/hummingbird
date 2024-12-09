//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2023-2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOCore
import NIOHTTPTypes

/// AsyncSequence used by consumeWithInboundCloseHandler
///
/// It will provide the buffers output by the ResponseBody and when that finishes will start
/// iterating what is left of the underlying request part stream, and continue iterating until
/// it hits the next head
struct RequestBodyMergedWithUnderlyingRequestPartIterator<Base: AsyncSequence>: AsyncSequence where Base.Element == ByteBuffer {
    typealias Element = HTTPRequestPart
    let base: Base
    let underlyingIterator: NIOAsyncChannelInboundStream<HTTPRequestPart>.AsyncIterator

    struct AsyncIterator: AsyncIteratorProtocol {
        enum CurrentAsyncIterator {
            case base(Base.AsyncIterator, underlying: NIOAsyncChannelInboundStream<HTTPRequestPart>.AsyncIterator)
            case underlying(NIOAsyncChannelInboundStream<HTTPRequestPart>.AsyncIterator)
            case done
        }
        var current: CurrentAsyncIterator

        init(iterator: Base.AsyncIterator, underlying: NIOAsyncChannelInboundStream<HTTPRequestPart>.AsyncIterator) {
            self.current = .base(iterator, underlying: underlying)
        }

        mutating func next() async throws -> HTTPRequestPart? {
            switch self.current {
            case .base(var base, let underlying):
                if let element = try await base.next() {
                    self.current = .base(base, underlying: underlying)
                    return .body(element)
                } else {
                    self.current = .underlying(underlying)
                    return .end(nil)
                }

            case .underlying(var underlying):
                while true {
                    let part = try await underlying.next()
                    if case .head = part {
                        self.current = .done
                        return part
                    }
                }
                self.current = .underlying(underlying)
                return nil

            case .done:
                return nil
            }
        }
    }

    func makeAsyncIterator() -> AsyncIterator {
        .init(iterator: base.makeAsyncIterator(), underlying: underlyingIterator)
    }
}

extension RequestBody {
    func mergeWithUnderlyingRequestPartIterator(
        _ iterator: NIOAsyncChannelInboundStream<HTTPRequestPart>.AsyncIterator
    ) -> RequestBodyMergedWithUnderlyingRequestPartIterator<Self> {
        .init(base: self, underlyingIterator: iterator)
    }
}
