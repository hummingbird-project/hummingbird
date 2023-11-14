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
import HummingbirdFoundation
import Logging
import MiddlewareModule
import NIOCore
import NIOPosix

struct MyRequestContext: HBRequestContext {
    /// core context
    public var coreContext: HBCoreRequestContext

    ///  Initialize an `HBRequestContext`
    /// - Parameters:
    ///   - applicationContext: Context from Application that instigated the request
    ///   - channelContext: Context providing source for EventLoop
    public init(
        applicationContext: HBApplicationContext,
        channel: Channel,
        logger: Logger
    ) {
        self.coreContext = .init(applicationContext: applicationContext, channel: channel, logger: logger)
    }
}

// get environment
let hostname = HBEnvironment.shared.get("SERVER_HOSTNAME") ?? "127.0.0.1"
let port = HBEnvironment.shared.get("SERVER_PORT", as: Int.self) ?? 8080

func JsonRouteGroup<Context: HBRequestContext>() -> some HBMiddlewareProtocol<Context> {
    return RouteGroup("json") {
        Get { _, _ in
            return ["message": "Hello, world"]
        }
    }
}

// create app
let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
defer { try? elg.syncShutdownGracefully() }
var router = HBRouter(context: MyRequestContext.self) {
    HBLogRequestsMiddleware(.info)
    Get { _, _ in
        return "Hello, world"
    }
    Post { request, _ in
        return HBResponse(status: .ok, body: .init(asyncSequence: request.body))
    }
    JsonRouteGroup()
}

var app = HBApplication(
    responder: router,
    configuration: .init(
        address: .hostname(hostname, port: port),
        serverName: "Hummingbird"
    ),
    eventLoopGroupProvider: .shared(elg)
)
app.logger.logLevel = .debug
app.encoder = JSONEncoder()
app.decoder = JSONDecoder()

// configure app

// run app
try await app.runService()
