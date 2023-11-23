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
import NIOCore
import NIOPosix

// get environment
let hostname = HBEnvironment.shared.get("SERVER_HOSTNAME") ?? "127.0.0.1"
let port = HBEnvironment.shared.get("SERVER_PORT", as: Int.self) ?? 8080

// create app
let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
defer { try? elg.syncShutdownGracefully() }

struct MyApplication: HBApplication {
    typealias Context = HBBasicRequestContext

    func buildResponder() -> some HBResponder<Context> {
        let router = HBRouterBuilder()
        // number of raw requests
        // ./wrk -c 128 -d 15s -t 8 http://localhost:8080
        router.get { _, _ in
            return "Hello, world"
        }

        // request with a body
        // ./wrk -c 128 -d 15s -t 8 -s scripts/post.lua http://localhost:8080
        router.post(options: .streamBody) { request, _ in
            return HBResponse(status: .ok, body: .init(asyncSequence: request.body))
        }

        // return JSON
        // ./wrk -c 128 -d 15s -t 8 http://localhost:8080/json
        router.get("json") { _, _ in
            return ["message": "Hello, world"]
        }
        return router.buildResponder()
    }
    let eventLoopGroup: EventLoopGroup = elg
    var encoder: HBRequestDecoder { JSONDecoder() }
    var decoder: HBResponseEncoder { JSONEncoder() }
    let logger: Logger = {
        var logger = Logger(label: "Test")
        logger.logLevel = .debug
        return logger
    }()
}
/*var app = HBApplication(
    responder: router.buildResponder(),
    configuration: .init(
        address: .hostname(hostname, port: port),
        serverName: "Hummingbird"
    ),
    eventLoopGroupProvider: .shared(elg)
)
app.logger.logLevel = .debug
app.encoder = JSONEncoder()
app.decoder = JSONDecoder()*/

// configure app

// run app
try await MyApplication().runService()
