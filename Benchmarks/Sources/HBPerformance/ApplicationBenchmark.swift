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
import NIO
import NIOPosix

protocol ApplicationBenchmarker {
    func setUp(_ application: HBApplication) throws
    func run(_ application: HBApplication) throws
}

class HBApplicationBenchmark<AB: ApplicationBenchmarker>: Benchmark {
    var eventLoopGroup: EventLoopGroup!
    var application: HBApplication!
    let configuration: HBApplication.Configuration
    let applicationBenchmarker: AB

    init(_ applicationBenchmarker: AB, configuration: HBApplication.Configuration = .init()) {
        self.applicationBenchmarker = applicationBenchmarker
        self.configuration = configuration
    }

    func setUp() throws {
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.application = HBApplication(configuration: self.configuration, eventLoopGroupProvider: .shared(self.eventLoopGroup))
        try self.applicationBenchmarker.setUp(self.application)
        try self.application.start()
    }

    func run() throws {
        try self.applicationBenchmarker.run(self.application)
    }

    func tearDown() {
        self.application.stop()
        try self.eventLoopGroup.syncShutdownGracefully()
    }
}