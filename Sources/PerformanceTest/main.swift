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
import NIOPosix

// get environment
let hostname = HBEnvironment.shared.get("SERVER_HOSTNAME") ?? "127.0.0.1"
let port = HBEnvironment.shared.get("SERVER_PORT", as: Int.self) ?? 8081

// create app
let elg = MultiThreadedEventLoopGroup(numberOfThreads: 2)
defer { try? elg.syncShutdownGracefully() }
let app = HBApplication(
    configuration: .init(
        address: .hostname(hostname, port: port),
        serverName: "Hummingbird"
    ),
    eventLoopGroupProvider: .shared(elg)
)
app.encoder = JSONEncoder()
app.decoder = JSONDecoder()

// configure app

// number of raw requests
// ./wrk -c 128 -d 15s -t 8 http://localhost:8080
app.router.get { _ in
    return "Hello, world"
}

// request with a body
// ./wrk -c 128 -d 15s -t 8 -s scripts/post.lua http://localhost:8080
app.router.post { request in
    return request.body.buffer
}

// return JSON
// ./wrk -c 128 -d 15s -t 8 http://localhost:8080/json
app.router.get("json") { _ in
    return ["message": "Hello, world"]
}

// run app
try app.run()
