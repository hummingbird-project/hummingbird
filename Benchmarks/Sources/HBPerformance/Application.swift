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
import NIOHTTP1

public struct BasicBenchmark: HBApplicationBenchmark {
    let iterations: Int

    public init(iterations: Int) {
        self.iterations = iterations
    }

    public func setUp(_ application: HBApplication) throws {
        application.router.get("/") { _ -> HTTPResponseStatus in
            .ok
        }
    }

    public func warmUp(_ application: HBApplication, _ client: HBXCTClient) throws {
        for _ in 0..<100 {
            _ = try client.get("/").wait()
        }
    }

    public func run(_ application: HBApplication, _ client: HBXCTClient) throws {
        for _ in 0..<self.iterations {
            _ = try client.get("/").wait()
        }
    }
}