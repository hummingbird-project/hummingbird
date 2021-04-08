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

import AsyncHTTPClient
import Hummingbird
import NIO
import NIOHTTP1
import XCTest

/// Test using a live server and AsyncHTTPClient
struct HBXCTLive: HBXCT {
    init(configuration: HBApplication.Configuration) {
        guard let port = configuration.address.port else {
            preconditionFailure("Cannot test application bound to unix domain socket")
        }
        self.port = port
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.client = HTTPClient(eventLoopGroupProvider: .shared(self.eventLoopGroup))
    }

    /// Start tests
    func start(application: HBApplication) {
        application.start()
    }

    /// Stop tests
    func stop(application: HBApplication) {
        XCTAssertNoThrow(_ = try self.client.syncShutdown())
        application.stop()
    }

    /// Send request and call test callback on the response returned
    func execute(
        uri: String,
        method: HTTPMethod,
        headers: HTTPHeaders = [:],
        body: ByteBuffer? = nil
    ) -> EventLoopFuture<HBXCTResponse> {
        let url = "http://localhost:\(port)\(uri)"
        do {
            let request = try HTTPClient.Request(url: url, method: method, headers: headers, body: body.map { .byteBuffer($0) })
            return self.client.execute(request: request)
                .map { response in
                    return .init(status: response.status, headers: response.headers, body: response.body)
                }
        } catch {
            return self.eventLoopGroup.next().makeFailedFuture(error)
        }
    }

    let eventLoopGroup: EventLoopGroup
    var port: Int
    let client: HTTPClient
}
