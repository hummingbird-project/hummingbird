//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import HummingbirdCore
import NIOSSL

extension HBHTTPChannelBuilder {
    public static func tls<BaseChannel: HBChildChannel>(
        _ base: HBHTTPChannelBuilder<BaseChannel> = .http1(),
        tlsConfiguration: TLSConfiguration
    ) throws -> HBHTTPChannelBuilder<TLSChannel<BaseChannel>> {
        return .init { responder in
            return try TLSChannel(base.build(responder), tlsConfiguration: tlsConfiguration)
        }
    }
}
