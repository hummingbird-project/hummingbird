//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import Hummingbird
import Logging
import NIOCore
import NIOPosix

// get environment
let env = Environment()
let hostname = env.get("SERVER_HOSTNAME") ?? "127.0.0.1"
let port = env.get("SERVER_PORT", as: Int.self) ?? 8080

// create app
let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
var router = Router()
router.addMiddleware {
    FileMiddleware()
}

// number of raw requests
// ./wrk -c 128 -d 15s -t 8 http://localhost:8080
router.get { _, _ in
    "Hello, world"
}

// request with a body
// ./wrk -c 128 -d 15s -t 8 -s scripts/post.lua http://localhost:8080
router.post { request, _ in
    Response(status: .ok, body: .init(asyncSequence: request.body))
}

struct Object: ResponseEncodable {
    let message: String
}

// return JSON
// ./wrk -c 128 -d 15s -t 8 http://localhost:8080/json
router.get("json") { _, _ in
    Object(message: "Hello, world")
}

// return JSON
// ./wrk -c 128 -d 15s -t 8 http://localhost:8080/json
router.get("wait") { _, _ in
    try await Task.sleep(for: .seconds(8))
    return "I waited"
}

var app = Application(
    responder: router.buildResponder(),
    configuration: .init(
        address: .hostname(hostname, port: port),
        serverName: "Hummingbird"
    ),
    eventLoopGroupProvider: .shared(elg)
)
app.logger.logLevel = .debug

// configure app

// run app
try await app.runService()
