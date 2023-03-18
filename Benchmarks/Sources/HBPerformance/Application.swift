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
import HummingbirdXCT
import NIOCore
import NIOHTTP1

/// Benchmark basic GET call which return 200
public struct BasicBenchmark: HBApplicationBenchmark {
    public init() {}

    public func setUp(_ application: HBApplication) throws {
        application.router.get("/") { _ -> HTTPResponseStatus in
            .ok
        }
    }

    public func singleIteration(_ client: HBXCT) -> EventLoopFuture<HBXCTResponse> {
        client.execute(uri: "/", method: .GET, headers: [:], body: nil)
    }
}

/// Benchmark  POST call with body
public struct RequestBodyBenchmark: HBApplicationBenchmark {
    let body: ByteBuffer

    public init(bufferSize: Int) {
        self.body = randomBuffer(size: bufferSize)
    }

    public func setUp(_ application: HBApplication) throws {
        application.router.post("/") { _ -> HTTPResponseStatus in
            .ok
        }
    }

    public func singleIteration(_ client: HBXCT) -> EventLoopFuture<HBXCTResponse> {
        client.execute(uri: "/", method: .POST, headers: [:], body: self.body)
    }
}

/// Benchmark basic GET call which returns a buffer
public struct ResponseBodyBenchmark: HBApplicationBenchmark {
    let body: ByteBuffer

    public init(bufferSize: Int) {
        self.body = randomBuffer(size: bufferSize)
    }

    public func setUp(_ application: HBApplication) throws {
        application.router.get("/") { _ -> ByteBuffer in
            self.body
        }
    }

    public func singleIteration(_ client: HBXCT) -> EventLoopFuture<HBXCTResponse> {
        client.execute(uri: "/", method: .GET, headers: [:], body: nil)
    }
}
