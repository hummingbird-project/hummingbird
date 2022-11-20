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

import HummingbirdCore
import HummingbirdCoreXCT
import NIOCore
import NIOHTTP1

struct TestResponder: HBHTTPResponder {
    func respond(to request: HBHTTPRequest, context: ChannelHandlerContext, onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void) {
        let responseHead = HTTPResponseHead(version: .init(major: 1, minor: 1), status: .ok, headers: [:])
        let response = HBHTTPResponse(head: responseHead, body: .empty)
        onComplete(.success(response))
    }
}

func run(identifier: String) {
    do {
        let setup = try CoreSetup(TestResponder())

        measure(identifier: identifier) {
            let iterations = 1000
            for _ in 0..<iterations {
                let future = setup.client.get("/")
                _ = try? future.wait()
            }
            return iterations
        }
    } catch {
        print(error)
    }
}
