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

extension HBHTTPChannelSetupBuilder {
    public static func tls<BaseChannel: HBChannelSetup>(
        _ base: HBHTTPChannelSetupBuilder<BaseChannel>,
        tlsConfiguration: TLSConfiguration
    ) throws -> HBHTTPChannelSetupBuilder<TLSChannel<BaseChannel>> {
        return .init { responder in
            return try TLSChannel(base.build(responder), tlsConfiguration: tlsConfiguration)
        }
    }
}
