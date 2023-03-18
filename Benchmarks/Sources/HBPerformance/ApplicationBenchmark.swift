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
import NIOPosix

public protocol HBApplicationBenchmark {
    func setUp(_ application: HBApplication) throws
    func warmUp(_ application: HBApplication, _ client: HBXCTClient) throws
    func run(_ application: HBApplication, _ client: HBXCTClient) throws
}

public class HBApplicationBenchmarkWrapper<AB: HBApplicationBenchmark>: Benchmark {
    var eventLoopGroup: EventLoopGroup!
    var application: HBApplication!
    let configuration: HBApplication.Configuration
    let applicationBenchmarker: AB
    // setup separate client eventLoopGroup so it doesn't interfere with the server
    var clientEventLoopGroup: EventLoopGroup!
    var client: HBXCTClient!

    public init(_ applicationBenchmarker: AB, configuration: HBApplication.Configuration = .init(address: .hostname("127.0.0.1", port: 0))) {
        self.applicationBenchmarker = applicationBenchmarker
        self.configuration = configuration
    }

    public func setUp() throws {
        // server setup
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.application = HBApplication(configuration: self.configuration, eventLoopGroupProvider: .shared(self.eventLoopGroup))
        try self.applicationBenchmarker.setUp(self.application)
        // start server
        try self.application.start()

        // client setup
        self.clientEventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.client = .init(host: "localhost", port: self.application.server.port!, eventLoopGroupProvider: .shared(self.clientEventLoopGroup))
        self.client.connect()

        // warm up 
        try self.applicationBenchmarker.warmUp(self.application, self.client)
    }

    public func run() throws {
        try self.applicationBenchmarker.run(self.application, self.client)
    }

    public func tearDown() {
        do {
            try self.client.syncShutdown()
            self.application.stop()
            try self.clientEventLoopGroup.syncShutdownGracefully()
            try self.eventLoopGroup.syncShutdownGracefully()
        } catch {
            // do nothing
        }
    }
}