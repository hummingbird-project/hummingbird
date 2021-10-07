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

import Hummingbird
import HummingbirdCoreXCT
import NIO

class Setup {
    let elg: EventLoopGroup
    let app: HBApplication
    let client: HBXCTClient

    init(_ configure: (HBApplication) -> ()) throws {
        self.elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
        self.app = HBApplication(
            configuration: .init(logLevel: .error), 
            eventLoopGroupProvider: .shared(elg)
        )
        self.app.logger.logLevel = .error
        configure(app)

        try app.start()

        self.client = HBXCTClient(host: "localhost", port: app.server.port!, eventLoopGroupProvider: .createNew)
        client.connect()
    }

    deinit {
        try? self.client.syncShutdown()
        self.app.stop()
        self.app.wait()
        try? self.elg.syncShutdownGracefully()
    }
}