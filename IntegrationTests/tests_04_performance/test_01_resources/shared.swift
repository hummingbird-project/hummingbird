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
import HummingbirdCore
import HummingbirdCoreXCT
import NIO

class Setup {
    let elg: EventLoopGroup
    let app: HBApplication
    let client: HBXCTClient

    init(_ configure: (HBApplication) -> Void) throws {
        self.elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
        self.app = HBApplication(
            configuration: .init(logLevel: .error),
            eventLoopGroupProvider: .shared(self.elg)
        )
        self.app.logger.logLevel = .error
        configure(self.app)

        try self.app.start()

        self.client = HBXCTClient(host: "localhost", port: self.app.server.port!, eventLoopGroupProvider: .createNew)
        self.client.connect()
    }

    deinit {
        try? self.client.syncShutdown()
        self.app.stop()
        self.app.wait()
        try? self.elg.syncShutdownGracefully()
    }
}

class CoreSetup {
    let elg: EventLoopGroup
    let server: HBHTTPServer
    let client: HBXCTClient

    init(_ responder: HBHTTPResponder) throws {
        self.elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
        self.server = HBHTTPServer(
            group: self.elg,
            configuration: .init()
        )
        try self.server.start(responder: responder).wait()

        self.client = HBXCTClient(host: "localhost", port: self.server.port!, eventLoopGroupProvider: .createNew)
        self.client.connect()
    }

    deinit {
        try? self.client.syncShutdown()
        try? self.server.stop().wait()
        try? self.elg.syncShutdownGracefully()
    }
}

func randomBuffer(size: Int) -> ByteBuffer {
    var data = [UInt8](repeating: 0, count: size)
    data = data.map { _ in UInt8.random(in: 0...255) }
    return ByteBufferAllocator().buffer(bytes: data)
}
