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
import NIOHTTP1
import NIOTransportServices
import XCTest

/// Test using a live server and AsyncHTTPClient
class HBXCTLive: HBXCT {
    init(configuration: HBApplication.Configuration) {
        guard let port = configuration.address.port else {
            preconditionFailure("Cannot test application bound to unix domain socket")
        }
        self.port = port
        #if os(iOS)
        self.eventLoopGroup = NIOTSEventLoopGroup()
        #else
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        #endif
        self.client = HBHTTPClientConnection(host: "localhost", port: port, eventLoopGroupProvider: .createNew)
    }

    /// Start tests
    func start(application: HBApplication) throws {
        do {
            try application.start()
            client.connect()
        } catch {
            // if start fails then shutdown client
            try self.client.syncShutdown()
            throw error
        }
    }

    /// Stop tests
    func stop(application: HBApplication) {
        XCTAssertNoThrow(_ = try self.client.syncShutdown())
        application.stop()
        application.wait()
        try? self.eventLoopGroup.syncShutdownGracefully()
    }

    /// Send request and call test callback on the response returned
    func execute(
        uri: String,
        method: HTTPMethod,
        headers: HTTPHeaders = [:],
        body: ByteBuffer? = nil
    ) -> EventLoopFuture<HBXCTResponse> {
        var headers = headers
        headers.replaceOrAdd(name: "connection", value: "keep-alive")
        headers.replaceOrAdd(name: "host", value: "localhost")
        let request = HBHTTPClient.Request(uri, method: method, headers: headers, body: body)
        self.client.execute(request)
        return self.client.getResponse()
            .map { response in
                return .init(status: response.status, headers: response.headers, body: response.body)
            }
    }

    let eventLoopGroup: EventLoopGroup
    let port: Int
    let client: HBHTTPClientConnection
}
